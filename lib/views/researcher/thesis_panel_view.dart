import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/telemetry/telemetry_tracker.dart';
import '../../core/telemetry/telemetry_api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/purchase_session.dart';
import '../2_home/home_view.dart';
import '../11_survey/comparative_survey_view.dart';
import 'pretest_observation_view.dart';

class ThesisPanelView extends StatefulWidget {
  const ThesisPanelView({super.key});

  @override
  State<ThesisPanelView> createState() => _ThesisPanelViewState();
}

class _ThesisPanelViewState extends State<ThesisPanelView> {
  final TelemetryTracker _tracker = TelemetryTracker();
  final TelemetryApiClient _api = TelemetryApiClient();

  // Controladores de texto para registro
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String _gender = 'Masculino';
  String _frequency = 'Quincenal';

  List<Map<String, dynamic>> get _savedParticipants => _tracker.savedParticipants;
  bool get _isSyncing => _tracker.isSyncing;
  bool _isRegistering = false;
  bool _showNewEvaluationForm = false;

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_onTrackerUpdated);
    // Solo carga desde el servidor si aún no se han cargado participantes en memoria
    if (!_tracker.hasLoadedParticipants) {
      _syncActiveParticipantAndList(silent: true);
    }
  }

  void _onTrackerUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tracker.removeListener(_onTrackerUpdated);
    _codeController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  /// Sincroniza el participante activo y la lista completa con el servidor (bajo demanda o por refresh)
  Future<void> _syncActiveParticipantAndList({bool silent = false}) async {
    try {
      await Future.wait([
        _tracker.syncActiveParticipantFromServer(),
        _tracker.refreshParticipants(silent: silent),
      ]);
    } catch (_) {
      // Ignorar fallas momentáneas
    }
  }

  /// Calcula el siguiente código correlativo automáticamente (P01, P02, P03...)
  String _getNextParticipantCode() {
    int maxNumber = 0;
    for (final p in _savedParticipants) {
      final rawCode = p['participant_code']?.toString().toUpperCase() ?? '';
      final match = RegExp(r'P?(\d+)').firstMatch(rawCode);
      if (match != null) {
        final numVal = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (numVal > maxNumber) {
          maxNumber = numVal;
        }
      }
    }
    if (_tracker.hasActiveParticipant) {
      final match = RegExp(r'P?(\d+)')
          .firstMatch(_tracker.participantCode.toUpperCase());
      if (match != null) {
        final numVal = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (numVal > maxNumber) {
          maxNumber = numVal;
        }
      }
    }
    final nextNumber = maxNumber + 1;
    return 'P${nextNumber.toString().padLeft(2, '0')}';
  }

  void _openNewEvaluationForm() {
    setState(() {
      _showNewEvaluationForm = true;
      _codeController.text = _getNextParticipantCode();
      _nameController.clear();
      _ageController.clear();
    });
  }

  void _cancelNewEvaluationForm() {
    setState(() {
      _showNewEvaluationForm = false;
      _codeController.clear();
      _nameController.clear();
      _ageController.clear();
    });
  }

  Future<void> _registerAndStartParticipant() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor ingresa un código para el participante (ej. P01)',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Participante $code';
    final age = int.tryParse(_ageController.text.trim()) ?? 22;

    setState(() => _isRegistering = true);

    // 1. Guardar y activar en el servidor para que el otro dispositivo lo jale inmediatamente
    final ok = await _api.registerParticipant(
      participantCode: code,
      name: name,
      age: age,
      gender: _gender,
      cinemaFrequency: _frequency,
      notes: 'Registrado desde Panel de Evaluación',
    );

    if (!ok) {
      if (mounted) {
        setState(() => _isRegistering = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error),
                SizedBox(width: 8),
                Text('Error de Conexión'),
              ],
            ),
            content: const Text(
              'No se pudo registrar al participante en el servidor.\n\n'
              'Verifica que el dispositivo tenga conexión a internet o red e intenta nuevamente.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'ENTENDIDO',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    await _api.activateParticipant(code);

    // 2. Establecer como participante activo en TelemetryTracker local
    _tracker.setParticipant(code: code, name: name, testMode: 'posttest');

    // 3. Resetear sesión de compra para iniciar limpio
    PurchaseSession().resetSession();

    await _syncActiveParticipantAndList(silent: true);

    if (mounted) {
      setState(() {
        _isRegistering = false;
        _showNewEvaluationForm = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Participante "$name" ($code) registrado y sincronizado en la red.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startPostTestAndGivePhoneToUser() {
    _tracker.startSession();
    PurchaseSession().resetSession();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📱 Prueba iniciada para ${_tracker.participantName}. Entrega el celular al usuario.',
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeView()),
      (route) => false,
    );
  }

  void _finishCurrentEvaluation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Finalizar evaluación?'),
        content: Text(
          'Se guardará la evaluación de ${_tracker.participantName} (${_tracker.participantCode}) y quedará listo para el siguiente participante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              _tracker.finishSession(
                isCompleted: true,
                maxStepReached: 'Evaluación completada por investigador',
              );
              _tracker.clearParticipant();
              PurchaseSession().resetSession();

              _codeController.clear();
              _nameController.clear();
              _ageController.clear();

              setState(() {
                _showNewEvaluationForm = false;
              });

              // Desactivar en el servidor para que todos los dispositivos queden limpios
              await _api.clearActiveParticipant();
              await _syncActiveParticipantAndList(silent: true);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✓ Evaluación finalizada y guardada. Listo para nuevo participante.',
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'Finalizar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadExistingParticipant(Map<String, dynamic> p) async {
    final code = p['participant_code']?.toString() ?? '';
    final name = p['name']?.toString() ?? 'Participante $code';

    // Sincronizar en la red hacia todos los dispositivos
    await _api.activateParticipant(code);

    _tracker.setParticipant(code: code, name: name, testMode: 'posttest');

    setState(() {
      _showNewEvaluationForm = false;
    });

    await _syncActiveParticipantAndList(silent: true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Participante activo: "$name" ($code) sincronizado.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = _tracker.hasActiveParticipant;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.hub_outlined, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Panel de Evaluación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sincronizar ahora',
            onPressed: () => _syncActiveParticipantAndList(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _syncActiveParticipantAndList(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SI HAY PARTICIPANTE ACTIVO: MOSTRAR LOS 3 PASOS GUIADOS
              if (hasActive) ...[
                _buildActiveParticipantCard(),
                const SizedBox(height: 16),
                _buildStep1PretestCard(),
                const SizedBox(height: 14),
                _buildStep2PosttestCard(),
                const SizedBox(height: 14),
                _buildStep3SusSurveyCard(),
                const SizedBox(height: 20),
                _buildFinishEvaluationButton(),
                const SizedBox(height: 24),
              ],

              // FORMULARIO: SOLO SE MUESTRA SI SE PIDE EXPLÍCITAMENTE
              if (_showNewEvaluationForm) ...[
                _buildNewEvaluationFormCard(),
                const SizedBox(height: 20),
              ] else if (!hasActive) ...[
                // BOTÓN PARA PEDIR EXPLÍCITAMENTE UNA NUEVA EVALUACIÓN
                _buildRequestNewEvaluationCard(),
                const SizedBox(height: 20),
              ],

              // LISTA DE PARTICIPANTES REGISTRADOS
              if (_savedParticipants.isNotEmpty) ...[
                _buildSavedParticipantsCard(),
                const SizedBox(height: 20),
              ] else if (!hasActive && !_showNewEvaluationForm) ...[
                _buildEmptyStateCard(),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? get _activeParticipantData {
    if (!_tracker.hasActiveParticipant) return null;
    final code = _tracker.participantCode.toUpperCase();
    for (final p in _savedParticipants) {
      if (p['participant_code']?.toString().toUpperCase() == code) {
        return p;
      }
    }
    return null;
  }

  String _formatDuration(num? seconds) {
    if (seconds == null || seconds <= 0) return '0s';
    final s = seconds.toInt();
    final mins = s ~/ 60;
    final secs = s % 60;
    if (mins == 0) return '${secs}s';
    return '${mins}m ${secs}s';
  }

  Widget _buildActiveParticipantCard() {
    final activeData = _activeParticipantData;
    final hasPre = activeData?['has_pretest'] == true;
    final hasPost = activeData?['has_posttest'] == true;
    final hasComp = activeData?['has_comparative'] == true;
    final completedCount =
        (hasPre ? 1 : 0) + (hasPost ? 1 : 0) + (hasComp ? 1 : 0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completedCount == 3
              ? const Color(0xFF10B981)
              : AppColors.primary,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: completedCount == 3
                    ? const Color(0xFF10B981)
                    : AppColors.primary,
                child: Text(
                  _tracker.participantCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_tracker.participantName} (${_tracker.participantCode})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Progreso: $completedCount de 3 pasos completados',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: completedCount == 3
                            ? const Color(0xFF059669)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: completedCount == 3
                      ? const Color(0xFFECFDF5)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: completedCount == 3
                        ? const Color(0xFF10B981)
                        : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      completedCount == 3
                          ? Icons.check_circle
                          : Icons.pending_actions,
                      size: 13,
                      color: completedCount == 3
                          ? const Color(0xFF059669)
                          : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      completedCount == 3 ? 'COMPLETO' : '$completedCount/3',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: completedCount == 3
                            ? const Color(0xFF065F46)
                            : Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de los 3 pasos con checks visuales
          Row(
            children: [
              Expanded(
                child: _buildMiniStepProgressChip('Paso 1: Pre-test', hasPre),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStepProgressChip('Paso 2: Post-test', hasPost),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStepProgressChip(
                  'Paso 3: Cuestionario',
                  hasComp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStepProgressChip(String label, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: done ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
          width: done ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13,
            color: done ? const Color(0xFF059669) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: done ? FontWeight.bold : FontWeight.w500,
                color: done ? const Color(0xFF065F46) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1PretestCard() {
    final activeData = _activeParticipantData;
    final hasPre = activeData?['has_pretest'] == true;
    final preTime = activeData?['pretest_time_s'] as num?;
    final preErrors = activeData?['pretest_errors'] as num?;
    final preCompleted = activeData?['pretest_completed'] as bool?;

    return Card(
      elevation: hasPre ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasPre ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: hasPre ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasPre ? Icons.check_circle : Icons.timer_outlined,
                  color: hasPre
                      ? const Color(0xFF059669)
                      : Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Paso 1: Observación Pre-Test (App Oficial)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStepCheckBadge(hasPre),
              ],
            ),
            if (hasPre) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(
                      '⏱ ${_formatDuration(preTime)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '⚠ ${preErrors ?? 0} errores',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      preCompleted == false ? '✗ Abandonó' : '✓ Completó',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: preCompleted == false
                            ? AppColors.error
                            : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(
                    color: hasPre
                        ? const Color(0xFF10B981)
                        : Colors.blue.shade400,
                  ),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PretestObservationView(
                        participantCode: _tracker.participantCode,
                        testMode: 'pretest',
                      ),
                    ),
                  );
                  _syncActiveParticipantAndList(silent: true);
                },
                icon: Icon(
                  hasPre ? Icons.edit_note : Icons.play_arrow,
                  size: 18,
                ),
                label: Text(
                  hasPre
                      ? 'VER / EDITAR FICHA PRE-TEST'
                      : 'ABRIR FICHA PRE-TEST',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2PosttestCard() {
    final activeData = _activeParticipantData;
    final hasPost = activeData?['has_posttest'] == true;
    final postTime = activeData?['posttest_time_s'] as num?;
    final postErrors = activeData?['posttest_errors'] as num?;
    final postCompleted = activeData?['posttest_completed'] as bool?;

    return Card(
      elevation: hasPost ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasPost ? const Color(0xFF10B981) : AppColors.primary,
          width: hasPost ? 1.5 : 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasPost ? Icons.check_circle : Icons.phone_android,
                  color: hasPost ? const Color(0xFF059669) : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Paso 2: Prueba Post-Test (Prototipo)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStepCheckBadge(hasPost),
              ],
            ),
            if (hasPost) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(
                      '⏱ ${_formatDuration(postTime)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '⚠ ${postErrors ?? 0} errores',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      postCompleted == false ? '✗ Abandonó' : '✓ Completó',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: postCompleted == false
                            ? AppColors.error
                            : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 7,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(
                        color: hasPost
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade400,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PretestObservationView(
                            participantCode: _tracker.participantCode,
                            testMode: 'posttest',
                          ),
                        ),
                      );
                      _syncActiveParticipantAndList(silent: true);
                    },
                    icon: Icon(
                      hasPost ? Icons.edit_note : Icons.visibility_outlined,
                      size: 16,
                    ),
                    label: Text(
                      hasPost ? 'VER FICHA' : 'FICHA POST',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _startPostTestAndGivePhoneToUser,
                    icon: const Icon(Icons.touch_app, size: 16),
                    label: const Text(
                      'ENTREGAR CELULAR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3SusSurveyCard() {
    final activeData = _activeParticipantData;
    final hasComp = activeData?['has_comparative'] == true;
    final preSus = activeData?['pre_sus_score'] as num?;
    final postSus = activeData?['post_sus_score'] as num?;
    final diffSus = activeData?['diff_sus_score'] as num?;

    return Card(
      elevation: hasComp ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasComp ? const Color(0xFF10B981) : Colors.amber.shade700,
          width: hasComp ? 1.5 : 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasComp
                      ? Icons.check_circle
                      : Icons.assignment_turned_in_outlined,
                  color: hasComp
                      ? const Color(0xFF059669)
                      : Colors.amber.shade900,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Paso 3: Cuestionario Comparativo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStepCheckBadge(hasComp),
              ],
            ),
            if (hasComp) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Pre: ${preSus?.toStringAsFixed(1) ?? "-"} pts',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '➔',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Post: ${postSus?.toStringAsFixed(1) ?? "-"} pts',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                    if (diffSus != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(Δ ${diffSus >= 0 ? "+" : ""}${diffSus.toStringAsFixed(1)})',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: diffSus >= 0
                              ? const Color(0xFF059669)
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasComp
                      ? const Color(0xFF059669)
                      : const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ComparativeSurveyView(
                        participantCode: _tracker.participantCode,
                        participantName: _tracker.participantName,
                      ),
                    ),
                  );
                  _syncActiveParticipantAndList(silent: true);
                },
                icon: Icon(
                  hasComp ? Icons.edit_note : Icons.assignment_outlined,
                  size: 18,
                ),
                label: Text(
                  hasComp
                      ? 'VER / EDITAR CUESTIONARIO'
                      : 'ABRIR CUESTIONARIO (PRE VS POST)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCheckBadge(bool isCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981)
              : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12,
            color: isCompleted
                ? const Color(0xFF059669)
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            isCompleted ? 'COMPLETADO' : 'PENDIENTE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isCompleted
                  ? const Color(0xFF065F46)
                  : const Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishEvaluationButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: _finishCurrentEvaluation,
        icon: const Icon(Icons.check_circle_outline, size: 20),
        label: const Text(
          'FINALIZAR EVALUACIÓN Y GUARDAR',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Tarjeta limpia con botón para solicitar explícitamente iniciar una nueva evaluación
  Widget _buildRequestNewEvaluationCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nueva Evaluación de Sujeto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Presiona el botón para registrar un nuevo participante con código correlativo automático.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _openNewEvaluationForm,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text(
                  'INICIAR NUEVA EVALUACIÓN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formulario de registro (solo se muestra cuando se pide explícitamente)
  Widget _buildNewEvaluationFormCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.person_add_alt_1,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Registrar Nuevo Participante',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Cerrar formulario',
                  onPressed: _cancelNewEvaluationForm,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Completa los datos para iniciar.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Código y Edad (Código ya viene prellenado con correlativo automático)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Código',
                      hintText: 'Ej. P01, P02',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.badge_outlined),
                      helperStyle: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Edad',
                      hintText: 'Ej. 24',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Nombre
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre y Apellido',
                hintText: 'Ej. Juan Pérez',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),

            // Género
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(
                labelText: 'Género',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _gender = val);
              },
            ),
            const SizedBox(height: 12),

            // Frecuencia
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(
                labelText: 'Frecuencia de asistencia al cine',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Semanal',
                  child: Text('Semanal (1 vez por semana)'),
                ),
                DropdownMenuItem(
                  value: 'Quincenal',
                  child: Text('Quincenal (2 veces al mes)'),
                ),
                DropdownMenuItem(
                  value: 'Mensual',
                  child: Text('Mensual (1 vez al mes)'),
                ),
                DropdownMenuItem(
                  value: 'Rara vez',
                  child: Text('Rara vez (Pocas veces al año)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _frequency = val);
              },
            ),
            const SizedBox(height: 18),

            // Botón de acción para registrar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isRegistering ? null : _registerAndStartParticipant,
                child: _isRegistering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'REGISTRAR Y COMENZAR EVALUACIÓN',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _cancelNewEvaluationForm,
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedParticipantsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Participantes Registrados',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_savedParticipants.length} registrados',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_savedParticipants.length, (idx) {
              final p = _savedParticipants[idx];
              final pCode = p['participant_code']?.toString() ?? 'P';
              final pName = p['name']?.toString() ?? 'Participante';
              final pAge = p['age']?.toString() ?? '-';
              final pGender = p['gender']?.toString() ?? '-';
              final hasPre = p['has_pretest'] == true;
              final hasPost = p['has_posttest'] == true;
              final hasComp = p['has_comparative'] == true;
              final isActive =
                  p['is_active'] == true || _tracker.participantCode == pCode;

              final preTime = (p['pretest_time_s'] as num?)?.toDouble();
              final postTime = (p['posttest_time_s'] as num?)?.toDouble();
              final preErrors = p['pretest_errors'] as num?;
              final postErrors = p['posttest_errors'] as num?;
              final preSus = p['pre_sus_score'] as num?;
              final postSus = p['post_sus_score'] as num?;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFF0FDF4) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF10B981)
                        : Colors.grey.shade200,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabecera del participante
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: isActive
                              ? const Color(0xFF059669)
                              : AppColors.primaryLight,
                          child: Text(
                            pCode,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$pName ($pCode)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Edad: $pAge • Género: $pGender',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ACTIVO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          )
                        else
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _loadExistingParticipant(p),
                            child: const Text(
                              'Activar',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Resumen compacto de métricas
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      hasPre
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      size: 13,
                                      color: hasPre
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        hasPre
                                            ? 'Pre: ${_formatDuration(preTime)} (${preErrors ?? 0} err)'
                                            : 'Pre: Pendiente',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: hasPre
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: hasPre
                                              ? const Color(0xFF065F46)
                                              : const Color(0xFF64748B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      hasPost
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      size: 13,
                                      color: hasPost
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        hasPost
                                            ? 'Post: ${_formatDuration(postTime)} (${postErrors ?? 0} err)'
                                            : 'Post: Pendiente',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: hasPost
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: hasPost
                                              ? const Color(0xFF065F46)
                                              : const Color(0xFF64748B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (hasComp) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 13,
                                  color: Color(0xFF059669),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'SUS: Pre ${preSus != null ? preSus.toStringAsFixed(1) : "-"} pts ➔ Post ${postSus != null ? postSus.toStringAsFixed(1) : "-"} pts',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Acciones directas por participante (Pre, Post y Cuestionario)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(
                                color: hasPre
                                    ? const Color(0xFF10B981)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            icon: Icon(
                              hasPre ? Icons.edit_note : Icons.play_arrow,
                              size: 14,
                            ),
                            label: Text(
                              hasPre ? 'Ver Pre' : 'Llenar Pre',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PretestObservationView(
                                    participantCode: pCode,
                                    testMode: 'pretest',
                                  ),
                                ),
                              );
                              _syncActiveParticipantAndList(silent: true);
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(
                                color: hasPost
                                    ? const Color(0xFF10B981)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            icon: Icon(
                              hasPost ? Icons.edit_note : Icons.phone_android,
                              size: 14,
                            ),
                            label: Text(
                              hasPost ? 'Ver Post' : 'Llenar Post',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PretestObservationView(
                                    participantCode: pCode,
                                    testMode: 'posttest',
                                  ),
                                ),
                              );
                              _syncActiveParticipantAndList(silent: true);
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(
                                color: hasComp
                                    ? const Color(0xFF10B981)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            icon: Icon(
                              hasComp
                                  ? Icons.edit_note
                                  : Icons.assignment_outlined,
                              size: 14,
                            ),
                            label: Text(
                              hasComp ? 'Ver Cuest.' : 'Llenar Cuest.',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ComparativeSurveyView(
                                    participantCode: pCode,
                                    participantName: pName,
                                  ),
                                ),
                              );
                              _syncActiveParticipantAndList(silent: true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'No hay participantes registrados',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Presiona "Nueva Evaluación" para registrar al primer participante.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
