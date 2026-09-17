import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/telemetry/telemetry_api_client.dart';
import '../../core/telemetry/telemetry_tracker.dart';
import '../../core/theme/app_colors.dart';

class ComparativeSurveyView extends StatefulWidget {
  final String? participantCode;
  final String? participantName;

  const ComparativeSurveyView({
    super.key,
    this.participantCode,
    this.participantName,
  });

  @override
  State<ComparativeSurveyView> createState() => _ComparativeSurveyViewState();
}

class _ComparativeSurveyViewState extends State<ComparativeSurveyView> {
  final TelemetryTracker _tracker = TelemetryTracker();
  final TelemetryApiClient _api = TelemetryApiClient();

  late final TextEditingController _participantController;
  final TextEditingController _commentsController = TextEditingController();

  bool _isSubmitting = false;

  // 10 respuestas de la escala SUS para Pre-test (App Oficial Cinemark)
  // Valores típicos balanceados iniciales
  final Map<int, int> _preAnswers = {
    1: 3, // Deseo de uso regular
    2: 4, // Complejidad innecesaria (alta)
    3: 2, // Facilidad de uso (baja)
    4: 3, // Apoyo técnico
    5: 2, // Funciones integradas (regular/baja)
    6: 4, // Inconsistencia (alta)
    7: 3, // Rapidez de aprendizaje (regular)
    8: 4, // Engorroso / pesado (alto)
    9: 2, // Seguridad y confianza (baja)
    10: 3, // Necesitó aprender muchas cosas
  };

  // 10 respuestas de la escala SUS para Post-test (Prototipo Mejorado)
  final Map<int, int> _postAnswers = {
    1: 5, // Deseo de uso (alto)
    2: 1, // Complejidad innecesaria (mínima)
    3: 5, // Facilidad de uso (máxima)
    4: 1, // Apoyo técnico (no necesario)
    5: 5, // Funciones integradas (excelente)
    6: 1, // Inconsistencia (ninguna)
    7: 5, // Rapidez de aprendizaje (inmediato)
    8: 1, // Engorroso / pesado (muy ligero)
    9: 5, // Seguridad y confianza (alta)
    10: 1, // Aprendizaje previo (intuitivo)
  };

  // Heurísticas complementarias de la Tesis (1 a 5)
  int _heuristicErrorPre = 2; // Prevención de errores en app oficial
  int _heuristicErrorPost = 5; // Prevención de errores en prototipo
  int _heuristicSeatsPre = 2; // Claridad de asientos y zoom en app oficial
  int _heuristicSeatsPost = 5; // Claridad de asientos y zoom en prototipo
  int _heuristicTimerPre = 2; // Visibilidad de tiempo en app oficial
  int _heuristicTimerPost = 5; // Visibilidad de tiempo en prototipo

  String _preferredSystem = 'Prototipo';

  final List<String> _susQuestions = [
    'Me gustaría usar este sistema con frecuencia en el futuro.',
    'Encontré el sistema innecesariamente complejo de usar.',
    'Pensé que el sistema era intuitivo y fácil de usar.',
    'Necesitaría el apoyo de una persona técnica para utilizarlo.',
    'Sentí que las funciones del sistema estaban bien organizadas e integradas.',
    'Percibí demasiada inconsistencia o confusión en el sistema.',
    'Imagino que la mayoría de usuarios aprendería a usarlo rápidamente.',
    'Encontré el sistema muy engorroso, lento o pesado de manejar.',
    'Me sentí seguro/a, confiado/a y en control durante el proceso.',
    'Necesité aprender demasiadas cosas antes de poder completarlo.',
  ];

  @override
  void initState() {
    super.initState();
    final initialCode = widget.participantCode ??
        (_tracker.participantCode.isNotEmpty && _tracker.participantCode != 'ANONIMO'
            ? _tracker.participantCode
            : '');
    _participantController = TextEditingController(text: initialCode);
  }

  @override
  void dispose() {
    _participantController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  double _calculateSus(Map<int, int> answers) {
    int positives = (answers[1]! - 1) +
        (answers[3]! - 1) +
        (answers[5]! - 1) +
        (answers[7]! - 1) +
        (answers[9]! - 1);
    int negatives = (5 - answers[2]!) +
        (5 - answers[4]!) +
        (5 - answers[6]!) +
        (5 - answers[8]!) +
        (5 - answers[10]!);
    return (positives + negatives) * 2.5;
  }

  String _getAdjective(double score) {
    if (score >= 85.0) return 'Excelente (Grade A)';
    if (score >= 70.0) return 'Bueno (Grade B)';
    if (score >= 50.0) return 'Regular (Grade C)';
    if (score >= 35.0) return 'Pobre (Grade D)';
    return 'Inaceptable (Grade F)';
  }

  Color _getScoreColor(double score) {
    if (score >= 85.0) return const Color(0xFF10B981);
    if (score >= 70.0) return const Color(0xFF3B82F6);
    if (score >= 50.0) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Future<void> _submitSurvey() async {
    final code = _participantController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor indica el código del participante (ej: P01)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final preScore = _calculateSus(_preAnswers);
    final postScore = _calculateSus(_postAnswers);
    final diffScore = roundDouble(postScore - preScore, 2);

    final res = await _api.submitComparativeSurvey(
      participantCode: code,
      preAnswers: _preAnswers,
      postAnswers: _postAnswers,
      heuristicErrorPre: _heuristicErrorPre,
      heuristicErrorPost: _heuristicErrorPost,
      heuristicSeatsPre: _heuristicSeatsPre,
      heuristicSeatsPost: _heuristicSeatsPost,
      heuristicTimerPre: _heuristicTimerPre,
      heuristicTimerPost: _heuristicTimerPost,
      preferredSystem: _preferredSystem,
      comments: _commentsController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (res != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              const SizedBox(width: 10),
              Text(
                '¡Evaluación Comparativa Lista!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se registraron exitosamente las calificaciones de $code para la Tesis de Usabilidad.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'App Oficial (Pre-test):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${preScore.toStringAsFixed(1)} pts (${_getAdjective(preScore).split(' ')[0]})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(preScore),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Prototipo (Post-test):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${postScore.toStringAsFixed(1)} pts (${_getAdjective(postScore).split(' ')[0]})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(postScore),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Impacto / Mejora:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '+${diffScore.toStringAsFixed(1)} pts',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop({
                  'pre_sus': preScore,
                  'post_sus': postScore,
                  'diff_sus': diffScore,
                  'participant_code': code,
                });
              },
              child: const Text('LISTO / CONTINUAR'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al conectar con la API. Verifica que uvicorn esté activo.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  double roundDouble(double val, int places) {
    return double.parse(val.toStringAsFixed(places));
  }

  @override
  Widget build(BuildContext context) {
    final preScore = _calculateSus(_preAnswers);
    final postScore = _calculateSus(_postAnswers);
    final diffScore = roundDouble(postScore - preScore, 2);
    final pctImp = preScore > 0 ? roundDouble(((postScore - preScore) / preScore) * 100.0, 1) : 0.0;

    final partName = widget.participantName ??
        (_tracker.participantName.isNotEmpty
            ? _tracker.participantName
            : 'Participante ${_participantController.text}');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Paso 3: Cuestionario Comparativo',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera Informativa
            // Container(
            //   padding: const EdgeInsets.all(16),
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     borderRadius: BorderRadius.circular(14),
            //     border: Border.all(color: Colors.grey.shade200),
            //     boxShadow: [
            //       BoxShadow(
            //         color: Colors.black.withValues(alpha: 0.03),
            //         blurRadius: 8,
            //         offset: const Offset(0, 2),
            //       ),
            //     ],
            //   ),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Row(
            //         children: [
            //           Container(
            //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            //             decoration: BoxDecoration(
            //               color: AppColors.primary.withValues(alpha: 0.1),
            //               borderRadius: BorderRadius.circular(6),
            //             ),
            //             child: Text(
            //               'EXPERIMENTO CUASIEXPERIMENTAL',
            //               style: GoogleFonts.inter(
            //                 fontSize: 10,
            //                 fontWeight: FontWeight.w800,
            //                 color: AppColors.primary,
            //                 letterSpacing: 0.5,
            //               ),
            //             ),
            //           ),
            //           const Spacer(),
            //           Text(
            //             'ISO 9241-11 / Escala SUS',
            //             style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
            //           ),
            //         ],
            //       ),
            //       const SizedBox(height: 10),
            //       Text(
            //         'Comparativo Pre-Test vs Post-Test',
            //         style: GoogleFonts.outfit(
            //           fontSize: 17,
            //           fontWeight: FontWeight.bold,
            //           color: AppColors.textPrimary,
            //         ),
            //       ),
            //       const SizedBox(height: 6),
            //       Text(
            //         'Para cada afirmación, califica de 1 (Muy en desacuerdo) a 5 (Muy de acuerdo) a ambos sistemas: la App Oficial de Cinemark que probaste primero y el Nuevo Prototipo.',
            //         style: GoogleFonts.inter(
            //           fontSize: 12,
            //           color: AppColors.textSecondary,
            //           height: 1.4,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            // const SizedBox(height: 14),

            // Identificación de Participante
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    radius: 18,
                    child: Text(
                      _participantController.text.isNotEmpty
                          ? _participantController.text.substring(0, 1)
                          : 'P',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'Código: ${_participantController.text} • Sujeto del Estudio',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Dashboard en Vivo: Puntajes SUS Pre vs Post
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'PUNTUACIONES CALCULADAS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Tarjeta PRE-TEST
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.phone_android, size: 12, color: Color(0xFF94A3B8)),
                                  SizedBox(width: 4),
                                  Text(
                                    'APP OFICIAL (PRE)',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${preScore.toStringAsFixed(1)} pts',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _getScoreColor(preScore),
                                ),
                              ),
                              Text(
                                _getAdjective(preScore).split(' ')[0],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getScoreColor(preScore),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tarjeta POST-TEST
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.star, size: 12, color: Color(0xFF34D399)),
                                  SizedBox(width: 4),
                                  Text(
                                    'PROTOTIPO (POST)',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF34D399),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${postScore.toStringAsFixed(1)} pts',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF34D399),
                                ),
                              ),
                              Text(
                                _getAdjective(postScore).split(' ')[0],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF34D399),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Banner de variación
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.trending_up, size: 16, color: Color(0xFF34D399)),
                        const SizedBox(width: 6),
                        Text(
                          'Diferencia de Usabilidad: +${diffScore.toStringAsFixed(1)} pts (+${pctImp.toStringAsFixed(1)}% de satisfacción)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF34D399),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECCIÓN 1: 10 PREGUNTAS DEL SUS COMPARATIVAS
            const Text(
              'PARTE 1: ESCALA SYSTEM USABILITY SCALE (SUS)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Evalúa el comportamiento de ambos sistemas en cada aspecto:',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            ...List.generate(10, (index) {
              final qNum = index + 1;
              return _buildComparativeQuestionCard(qNum, _susQuestions[index]);
            }),

            const SizedBox(height: 20),

            // SECCIÓN 2: HEURÍSTICAS ESPECÍFICAS DE LA TESIS
            const Text(
              'PARTE 2: EVALUACIÓN HEURÍSTICA Y CONTROL COGNITIVO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Métricas complementarias de las dimensiones de la tesis:',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            _buildHeuristicItemCard(
              title: 'Prevención de Errores y Validaciones',
              description: '¿Qué tan claro fue el sistema para evitar que cometas errores en tu compra (cine equivocado, butaca errónea, cupones)?',
              preVal: _heuristicErrorPre,
              postVal: _heuristicErrorPost,
              onPreChanged: (v) => setState(() => _heuristicErrorPre = v),
              onPostChanged: (v) => setState(() => _heuristicErrorPost = v),
            ),
            _buildHeuristicItemCard(
              title: 'Selección de Butacas y Navegación de Sala',
              description: '¿Qué tan fácil y libre de frustración fue ampliar la sala con zoom y tocar tus asientos deseados?',
              preVal: _heuristicSeatsPre,
              postVal: _heuristicSeatsPost,
              onPreChanged: (v) => setState(() => _heuristicSeatsPre = v),
              onPostChanged: (v) => setState(() => _heuristicSeatsPost = v),
            ),
            _buildHeuristicItemCard(
              title: 'Visibilidad del Estado y Control del Tiempo',
              description: '¿Sentiste que conocías cuánto tiempo tenías para comprar, sin mensajes repentinos de expiración?',
              preVal: _heuristicTimerPre,
              postVal: _heuristicTimerPost,
              onPreChanged: (v) => setState(() => _heuristicTimerPre = v),
              onPostChanged: (v) => setState(() => _heuristicTimerPost = v),
            ),

            const SizedBox(height: 20),

            // SECCIÓN 3: PREFERENCIA GLOBAL
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preferencia Global del Usuario:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Si tuvieras que comprar tus entradas hoy en Cinemark, ¿cuál de las dos aplicaciones preferirías usar?',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _preferredSystem = 'AppOficial'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: _preferredSystem == 'AppOficial'
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _preferredSystem == 'AppOficial'
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                width: _preferredSystem == 'AppOficial' ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _preferredSystem == 'AppOficial'
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: _preferredSystem == 'AppOficial'
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'App Oficial\n(Actual)',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                          onTap: () => setState(() => _preferredSystem = 'Prototipo'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: _preferredSystem == 'Prototipo'
                                  ? AppColors.primaryLight
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _preferredSystem == 'Prototipo'
                                    ? AppColors.primary
                                    : Colors.grey.shade300,
                                width: _preferredSystem == 'Prototipo' ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _preferredSystem == 'Prototipo'
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: _preferredSystem == 'Prototipo'
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Nuevo Prototipo\n(Mejorado)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SECCIÓN 4: COMENTARIOS CUALITATIVOS
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comentarios Cualitativos del Participante:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '¿Qué diferencias sentiste entre ambos procesos? ¿Qué fue lo más fácil o difícil?',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _commentsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Apunta aquí las palabras del participante...',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botón de Envío
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _isSubmitting ? null : _submitSurvey,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _isSubmitting ? 'GUARDANDO COMPARATIVA...' : 'GUARDAR EVALUACIÓN COMPARATIVA',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildComparativeQuestionCard(int qNum, String questionText) {
    final preVal = _preAnswers[qNum] ?? 3;
    final postVal = _postAnswers[qNum] ?? 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enunciado
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$qNum',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  questionText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Calificación 1: APP OFICIAL (PRETEST)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📱 App Oficial de Cinemark (Pre-test):',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      'Calificación: $preVal / 5',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildLikertRow(
                  currentValue: preVal,
                  selectedColor: const Color(0xFF475569),
                  onChanged: (val) {
                    setState(() => _preAnswers[qNum] = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Calificación 2: PROTOTIPO (POSTTEST)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '⭐ Nuevo Prototipo (Post-test):',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Calificación: $postVal / 5',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildLikertRow(
                  currentValue: postVal,
                  selectedColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _postAnswers[qNum] = val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeuristicItemCard({
    required String title,
    required String description,
    required int preVal,
    required int postVal,
    required ValueChanged<int> onPreChanged,
    required ValueChanged<int> onPostChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 10),

          // Pre
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('App Oficial:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text('$preVal / 5', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          _buildLikertRow(
            currentValue: preVal,
            selectedColor: const Color(0xFF64748B),
            onChanged: onPreChanged,
          ),
          const SizedBox(height: 10),

          // Post
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nuevo Prototipo:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Text(
                '$postVal / 5',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildLikertRow(
            currentValue: postVal,
            selectedColor: AppColors.primary,
            onChanged: onPostChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLikertRow({
    required int currentValue,
    required Color selectedColor,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: List.generate(5, (i) {
        final score = i + 1;
        final isSelected = currentValue == score;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 4 ? 6.0 : 0.0),
            child: InkWell(
              onTap: () => onChanged(score),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? selectedColor : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: selectedColor.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      score == 1
                          ? 'Min'
                          : score == 5
                              ? 'Max'
                              : '',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
