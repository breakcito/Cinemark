import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/telemetry/telemetry_api_client.dart';
import '../../core/theme/app_colors.dart';

class PretestObservationView extends StatefulWidget {
  final String participantCode;
  final String testMode;

  const PretestObservationView({
    super.key,
    required this.participantCode,
    this.testMode = 'pretest',
  });

  @override
  State<PretestObservationView> createState() => _PretestObservationViewState();
}

class _PretestObservationViewState extends State<PretestObservationView> {
  final TelemetryApiClient _api = TelemetryApiClient();

  // Estado de carga inicial
  bool _isLoading = true;
  bool _isAlreadySaved = false;
  bool _loadError = false;

  // Cronómetro de la observación
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isTimerRunning = false;

  // Las 8 etapas completas del proceso de compra evaluado en la tesis
  final Map<String, int> _stageTimes = {
    'Inicio': 0,
    'Horarios': 0,
    'Tickets': 0,
    'Asientos': 0,
    'Confitería': 0,
    'Pago': 0,
    'Boleto': 0,
    'Historial': 0,
  };
  String _currentStage = 'Inicio';

  // Catálogo de errores comunes clasificados por cada etapa (fricciones reales de Cinemark y de la tesis)
  static const Map<String, List<Map<String, String>>> _stageCommonErrors = {
    'Inicio': [
      {'type': 'NotificacionesRepetitivas', 'desc': 'Modal de notificaciones repetitivo y molesto en cada ingreso'},
      {'type': 'CineLejano', 'desc': 'Sin GPS / eligió sede lejana por falta de ubicación automática'},
      {'type': 'BannerSinAccion', 'desc': 'Anuncio/banner de película no cliqueable o no redirige a cartelera'},
      {'type': 'PeliculaSinHorarios', 'desc': 'Película mostrada no cuenta con funciones en el cine del usuario'},
      {'type': 'FaltaBuscadorPeliculas', 'desc': 'No cuenta con buscador para encontrar títulos rápidamente'},
    ],
    'Horarios': [
      {'type': 'TiempoExpiradoSinReloj', 'desc': 'Mensaje de tiempo expirado repentino sin contador visible en pantalla'},
      {'type': 'HorarioSinButacas', 'desc': 'Eligió horario que ya no contaba con butacas disponibles en la sala'},
      {'type': 'ConfusionFecha', 'desc': 'Dificultad o confusión al alternar entre fechas de las funciones'},
      {'type': 'FormatoSalaConfuso', 'desc': 'No distingue claramente sala 2D, 3D, XD o D-BOX'},
    ],
    'Tickets': [
      {'type': 'CanjeCuponLento', 'desc': 'Tuvo que canjear códigos uno por uno en vez de ingresarlos en un solo lote'},
      {'type': 'TarifasConfusas', 'desc': 'Muestra tarifas caras innecesarias en vez de recomendar promociones vigentes'},
      {'type': 'DudaCantidadTarifa', 'desc': 'Duda o demora al calcular y seleccionar el subtotal de entradas'},
      {'type': 'RestriccionEdadNoVisible', 'desc': 'No especifica restricciones de edad o requisitos de menores'},
    ],
    'Asientos': [
      {'type': 'ZoomButacasFalla', 'desc': 'Zoom errático / requirió 2 a 3 intentos para ampliar correctamente la sala'},
      {'type': 'DesplazamientoSalaDificil', 'desc': 'Dificultad para desplazarse fluidamente entre las filas de la sala'},
      {'type': 'ButacasSeparadas', 'desc': 'Eligió por error butacas separadas al no visualizar el plano con claridad'},
      {'type': 'NoDistingueDisponibles', 'desc': 'Confusión visual entre butacas ocupadas, libres y preferenciales'},
      {'type': 'PantallaDesorientada', 'desc': 'No ubica dónde está la pantalla de proyección respecto a los asientos'},
    ],
    'Confitería': [
      {'type': 'ItemsExclusivosSocio', 'desc': 'Prioriza combos para socios exclusivos sin que el usuario sea miembro'},
      {'type': 'ItemNoDisponible', 'desc': 'Muestra en catálogo productos o combos agotados y no disponibles'},
      {'type': 'FaltaBuscador', 'desc': 'Tuvo que buscar combos manualmente por ausencia de buscador de dulcería'},
      {'type': 'CombosDesordenados', 'desc': 'Combos desordenados y difíciles de comparar en precio y contenido'},
      {'type': 'PersonalizacionDificil', 'desc': 'Dificultad para personalizar sabores de gaseosa o cancha'},
    ],
    'Pago': [
      {'type': 'ReingresoNombreTitular', 'desc': 'Tuvo que volver a ingresar el nombre del titular ya registrado'},
      {'type': 'ErrorFormatoTarjeta', 'desc': 'Falla o confusión al digitar número de tarjeta o fecha de vencimiento'},
      {'type': 'ConfusionPasarelaYape', 'desc': 'Duda o tropiezo al seleccionar método de pago entre Tarjeta y Yape'},
      {'type': 'ResumenSinDetalle', 'desc': 'Resumen de cobro poco detallado antes de confirmar la transacción'},
      {'type': 'DemoraConfirmacionPago', 'desc': 'Espera excesiva o inseguridad al procesar la pasarela de pago'},
    ],
    'Boleto': [
      {'type': 'QRSinDetalleSala', 'desc': 'Boleto/QR con información escueta (no especifica sala o ingreso claramente)'},
      {'type': 'MiedoPerderBoleto', 'desc': 'Inseguridad o temor de cerrar la app y perder el código QR de acceso'},
      {'type': 'SinDescargaQR', 'desc': 'No permite guardar el boleto en galería ni compartirlo fácilmente'},
    ],
    'Historial': [
      {'type': 'HistorialDificilUbicar', 'desc': 'Historial de compras confuso y difícil de encontrar en el menú'},
      {'type': 'NoEncuentraQREntrada', 'desc': 'No logró ubicar con rapidez el QR de su compra para entrar al cine'},
      {'type': 'BoletoNoVisibleRapido', 'desc': 'Ausencia de acceso directo en el inicio al boleto de la función próxima'},
      {'type': 'DetalleCompraIncompleto', 'desc': 'Falta comprobante o detalle de entradas y confitería en historial'},
    ],
  };

  // Errores observados registrados para este participante
  int _totalErrors = 0;
  final List<Map<String, dynamic>> _observedErrors = [];

  // Tasa de completitud (Dimensión Eficacia)
  bool _isCompleted = true;
  String _maxStepReached = 'Historial';

  // Controladores de texto
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customErrorController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingObservation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesController.dispose();
    _customErrorController.dispose();
    super.dispose();
  }

  /// Carga la observación previa del participante desde la base de datos
  Future<void> _loadExistingObservation() async {
    setState(() {
      _isLoading = true;
      _loadError = false;
    });
    final data = await _api.getObservationSheet(
      widget.participantCode,
      testMode: widget.testMode,
    );

    if (mounted) {
      if (data != null && data['found'] == true) {
        // Cargar datos previos
        final totalSecs = (data['total_duration_seconds'] as num?)?.toInt() ?? 0;
        final durations = data['step_durations'] as Map<String, dynamic>? ?? {};
        final errList = (data['errors'] as List<dynamic>?) ?? [];

        setState(() {
          _isAlreadySaved = true;
          _loadError = false;
          _secondsElapsed = totalSecs;
          _isCompleted = data['is_completed'] as bool? ?? true;
          _maxStepReached = data['max_step_reached'] as String? ?? 'Historial';
          _notesController.text = data['notes'] as String? ?? '';

          // Rellenar tiempos por etapa
          durations.forEach((key, val) {
            if (_stageTimes.containsKey(key)) {
              _stageTimes[key] = (val as num).toInt();
            }
          });

          // Rellenar errores
          _observedErrors.clear();
          for (final item in errList) {
            final m = Map<String, dynamic>.from(item as Map);
            _observedErrors.add({
              'step': m['step_name'] ?? _currentStage,
              'type': m['error_type'] ?? 'Error',
              'description': m['description'] ?? '',
              'timestamp': m['occurred_at'] ?? DateTime.now().toIso8601String(),
            });
          }
          _totalErrors = (data['total_errors'] as num?)?.toInt() ?? _observedErrors.length;
          _isLoading = false;
        });
      } else if (data != null && data['found'] == false) {
        setState(() {
          _isAlreadySaved = false;
          _loadError = false;
          _isLoading = false;
        });
      } else {
        // Error de red / backend inaccesible
        setState(() {
          _loadError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _toggleTimer() {
    setState(() {
      if (_isTimerRunning) {
        _timer?.cancel();
        _isTimerRunning = false;
      } else {
        _isTimerRunning = true;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() {
            _secondsElapsed++;
            _stageTimes[_currentStage] = (_stageTimes[_currentStage] ?? 0) + 1;
          });
        });
      }
    });
  }

  void _switchStage(String newStage) {
    setState(() {
      _currentStage = newStage;
    });
  }

  void _addPredefinedError(String type, String description) {
    setState(() {
      _totalErrors++;
      _observedErrors.add({
        'step': _currentStage,
        'type': type,
        'description': description,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error registrado en "$_currentStage": $type (+1)'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _addCustomError() {
    final text = _customErrorController.text.trim();
    if (text.isEmpty) return;
    _addPredefinedError('ErrorPersonalizado', text);
    _customErrorController.clear();
  }

  void _removeError(int index) {
    if (index >= 0 && index < _observedErrors.length) {
      setState(() {
        _observedErrors.removeAt(index);
        _totalErrors = _observedErrors.length;
      });
    }
  }

  String _formatSeconds(int totalSecs) {
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _saveObservation() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final double totalSecs = _secondsElapsed > 0 ? _secondsElapsed.toDouble() : 1.0;
    final Map<String, double> stepDurationsDouble = {};
    _stageTimes.forEach((key, val) {
      stepDurationsDouble[key] = val.toDouble();
    });

    final res = await _api.recordPretestObservation(
      participantCode: widget.participantCode,
      testMode: widget.testMode,
      cinemaName: widget.testMode == 'pretest'
          ? 'Cinemark Mallplaza Trujillo (App Oficial)'
          : 'Cinemark Prototipo Mejorado',
      movieTitle: widget.testMode == 'pretest'
          ? 'Evaluación App Oficial'
          : 'Evaluación Prototipo',
      totalDurationSeconds: totalSecs,
      isCompleted: _isCompleted,
      maxStepReached: _maxStepReached,
      totalErrors: _totalErrors,
      stepDurations: stepDurationsDouble,
      errors: _observedErrors,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : 'Ficha de observación guardada',
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (res != null && res['status'] == 'ok') {
        setState(() => _isAlreadySaved = true);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                SizedBox(width: 8),
                Text('Ficha Guardada con Éxito'),
              ],
            ),
            content: Text(
              'La ficha de observación del participante ${widget.participantCode} (${widget.testMode.toUpperCase()}) se sincronizó con el servidor.\n\n'
              '• Tiempo Total: ${_formatSeconds(_secondsElapsed)}\n'
              '• Total Errores: $_totalErrors\n'
              '• Completitud: ${_isCompleted ? "Éxito (100%)" : "Abandono / Falla"}\n'
              '• Etapa Máxima: $_maxStepReached',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('ENTENDIDO', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error),
                SizedBox(width: 8),
                Text('Error al Guardar Ficha'),
              ],
            ),
            content: Text(
              'No se pudo guardar la ficha en la base de datos MySQL.\n\n'
              'La API en ${_api.baseUrl} no respondió.\n'
              'Verifica que el servidor FastAPI esté iniciado con --host 0.0.0.0 y que ambos dispositivos estén en la misma red Wi-Fi.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ENTENDIDO', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPretest = widget.testMode == 'pretest';
    final currentStageErrors = _stageCommonErrors[_currentStage] ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          isPretest
              ? 'Ficha Pre-test: ${widget.participantCode} (App Oficial)'
              : 'Ficha Post-test: ${widget.participantCode} (Prototipo)',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // if (_isSaving)
          //   const Padding(
          //     padding: EdgeInsets.symmetric(horizontal: 12),
          //     child: Center(
          //       child: SizedBox(
          //         width: 18,
          //         height: 18,
          //         child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success),
          //       ),
          //     ),
          //   )
          // else
          //   Padding(
          //     padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          //     child: ElevatedButton.icon(
          //       style: ElevatedButton.styleFrom(
          //         backgroundColor: AppColors.success,
          //         foregroundColor: Colors.white,
          //         elevation: 0,
          //         padding: const EdgeInsets.symmetric(horizontal: 10),
          //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          //       ),
          //       icon: const Icon(Icons.save, size: 16),
          //       label: Text(
          //         _isAlreadySaved ? 'ACTUALIZAR' : 'GUARDAR',
          //         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          //       ),
          //       onPressed: _saveObservation,
          //     ),
          //   ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Recargar',
            onPressed: _isSaving ? null : _loadExistingObservation,
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Consultando ficha...', style: TextStyle(fontSize: 12)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // // Banner de estado: Error vs Ya guardado vs Nuevo
                  // if (_loadError)
                  //   Container(
                  //     margin: const EdgeInsets.only(bottom: 16),
                  //     padding: const EdgeInsets.all(12),
                  //     decoration: BoxDecoration(
                  //       color: AppColors.error.withValues(alpha: 0.1),
                  //       borderRadius: BorderRadius.circular(10),
                  //       border: Border.all(color: AppColors.error),
                  //     ),
                  //     child: Row(
                  //       children: [
                  //         const Icon(Icons.wifi_off, color: AppColors.error, size: 24),
                  //         const SizedBox(width: 10),
                  //         Expanded(
                  //           child: Column(
                  //             crossAxisAlignment: CrossAxisAlignment.start,
                  //             children: [
                  //               const Text(
                  //                 'Sin conexión con el servidor',
                  //                 style: TextStyle(
                  //                   fontSize: 12,
                  //                   fontWeight: FontWeight.bold,
                  //                   color: AppColors.error,
                  //                 ),
                  //               ),
                  //               const Text(
                  //                 'No se pudo verificar si existía una ficha previa.',
                  //                 style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //         TextButton(
                  //           onPressed: _loadExistingObservation,
                  //           child: const Text('REINTENTAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  //         ),
                  //       ],
                  //     ),
                  //   )
                  // else
                  //   Container(
                  //     padding: const EdgeInsets.all(12),
                  //     decoration: BoxDecoration(
                  //       color: _isAlreadySaved
                  //           ? AppColors.success.withValues(alpha: 0.1)
                  //           : const Color(0xFFFFF3E0),
                  //       borderRadius: BorderRadius.circular(10),
                  //       border: Border.all(
                  //         color: _isAlreadySaved ? AppColors.success : const Color(0xFFFFB74D),
                  //       ),
                  //     ),
                  //     child: Row(
                  //       children: [
                  //         Icon(
                  //           _isAlreadySaved ? Icons.cloud_done : Icons.science,
                  //           color: _isAlreadySaved ? AppColors.success : const Color(0xFFE65100),
                  //           size: 24,
                  //         ),
                  //         const SizedBox(width: 10),
                  //         Expanded(
                  //           child: Text(
                  //             _isAlreadySaved
                  //                 ? 'Ficha guardada cargada con éxito. Los datos se muestran abajo para consulta o edición.'
                  //                 : 'Observación del participante ${widget.participantCode} (${isPretest ? "App Oficial" : "Prototipo"}).',
                  //             style: TextStyle(
                  //               fontSize: 12,
                  //               fontWeight: FontWeight.w600,
                  //               color: _isAlreadySaved ? AppColors.success : const Color(0xFFE65100),
                  //             ),
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // const SizedBox(height: 16),

                  // 1. CRONÓMETRO GENERAL Y POR ETAPA
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TIEMPO TOTAL DE OBSERVACIÓN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatSeconds(_secondsElapsed),
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: _isTimerRunning ? AppColors.primary : AppColors.textPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton.icon(
                                  icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow),
                                  label: Text(_isTimerRunning ? 'PAUSAR' : 'INICIAR CRONÓMETRO'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isTimerRunning ? AppColors.warning : AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: _toggleTimer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('REINICIAR'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _timer?.cancel();
                                      _isTimerRunning = false;
                                      _secondsElapsed = 0;
                                      _stageTimes.updateAll((key, value) => 0);
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SELECTOR DE LAS 8 ETAPAS
                  const Text(
                    '1. Etapas del Proceso de Compra (Cronometraje):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Selecciona la etapa activa que el participante está recorriendo en este momento:',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _stageTimes.keys.map((stage) {
                      final isCurrent = stage == _currentStage;
                      final durationSecs = _stageTimes[stage] ?? 0;
                      return ChoiceChip(
                        label: Text('$stage (${_formatSeconds(durationSecs)})'),
                        selected: isCurrent,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isCurrent ? Colors.white : AppColors.textPrimary,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) _switchStage(stage);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 2. ERRORES OBSERVADOS ESPECÍFICOS DE LA ETAPA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '2. Errores Comunes en "$_currentStage":',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _totalErrors > 0
                              ? AppColors.error.withValues(alpha: 0.12)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_totalErrors errores',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _totalErrors > 0 ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Toca un botón rápido para registrar una falla observada en la etapa "$_currentStage":',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),

                  // CHIPS RÁPIDOS POR ETAPA
                  if (currentStageErrors.isNotEmpty)
                    Column(
                      children: currentStageErrors.map((errItem) {
                        final type = errItem['type'] ?? 'Error';
                        final desc = errItem['desc'] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          width: double.infinity,
                          child: InkWell(
                            onTap: () => _addPredefinedError(type, desc),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_circle, size: 18, color: AppColors.error),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          type,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          desc,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.touch_app, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No hay fallas predefinidas para esta etapa.', style: TextStyle(fontSize: 11)),
                    ),

                  const SizedBox(height: 8),

                  // AGREGAR OTRO ERROR PERSONALIZADO
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customErrorController,
                          decoration: InputDecoration(
                            hintText: 'Describir otro error observado en $_currentStage...',
                            hintStyle: const TextStyle(fontSize: 11),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: _addCustomError,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text('Agregar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // LISTA DE ERRORES REGISTRADOS (CON POSIBILIDAD DE BORRAR)
                  if (_observedErrors.isNotEmpty) ...[
                    const Text(
                      'Incidencias Registradas para esta sesión:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: _observedErrors.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final err = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    err['step'] ?? '',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${err['type']}: ${err['description']}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () => _removeError(idx),
                                  tooltip: 'Eliminar',
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. TASA DE COMPLETITUD (EFICACIA)
                  const Text(
                    '3. Tasa de Éxito / Completitud:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() {
                            _isCompleted = true;
                            _maxStepReached = 'Historial';
                          }),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _isCompleted
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isCompleted ? AppColors.success : AppColors.border,
                                width: _isCompleted ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: _isCompleted ? AppColors.success : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Completó Compra\n(Éxito 100%)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() {
                            _isCompleted = false;
                            _maxStepReached = _currentStage;
                          }),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(
                              color: !_isCompleted
                                  ? AppColors.error.withValues(alpha: 0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !_isCompleted ? AppColors.error : AppColors.border,
                                width: !_isCompleted ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  !_isCompleted ? Icons.cancel : Icons.radio_button_unchecked,
                                  color: !_isCompleted ? AppColors.error : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Abandonó Compra\n(Frustración / Falla)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. NOTAS DEL INVESTIGADOR
                  const Text(
                    '4. Notas y Observaciones Cualitativas:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Apunta aquí comentarios, dudas o reacciones del participante...',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 20),
              label: Text(
                _isSaving
                    ? 'GUARDANDO FICHA...'
                    : (_isAlreadySaved ? 'ACTUALIZAR FICHA GUARDADA' : 'GUARDAR FICHA DE OBSERVACIÓN'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving ? null : _saveObservation,
            ),
          ),
        ),
      ),
    );
  }
}
