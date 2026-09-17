import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/telemetry/telemetry_tracker.dart';
import '../../core/telemetry/telemetry_api_client.dart';

class SusSurveyView extends StatefulWidget {
  final String? sessionUuid;
  final String? participantCode;
  final String? testMode;

  const SusSurveyView({
    super.key,
    this.sessionUuid,
    this.participantCode,
    this.testMode,
  });

  @override
  State<SusSurveyView> createState() => _SusSurveyViewState();
}

class _SusSurveyViewState extends State<SusSurveyView> {
  final TelemetryTracker _tracker = TelemetryTracker();
  final TelemetryApiClient _api = TelemetryApiClient();

  late final TextEditingController _participantController;
  final TextEditingController _commentsController = TextEditingController();

  late String _testMode; // 'pretest' o 'posttest'
  bool _isSubmitting = false;

  // 10 respuestas de la escala SUS (inicializadas por defecto en valores balanceados)
  final Map<int, int> _answers = {
    1: 4,
    2: 1,
    3: 5,
    4: 1,
    5: 5,
    6: 1,
    7: 5,
    8: 1,
    9: 5,
    10: 1,
  };

  final List<String> _questions = [
    'Me gustaría usar esta aplicación de cine con frecuencia.',
    'Encontré la aplicación innecesariamente compleja.',
    'Pensé que la aplicación era fácil de usar.',
    'Necesitaría el apoyo de una persona técnica para usarla.',
    'Las funciones de la aplicación estaban bien integradas.',
    'Había demasiada inconsistencia en la aplicación.',
    'Imagino que la gente aprendería a usarla muy rápidamente.',
    'Encontré la aplicación muy engorrosa o pesada de usar.',
    'Me sentí muy seguro/a y con confianza usando la aplicación.',
    'Necesité aprender muchas cosas antes de poder usarla.',
  ];

  @override
  void initState() {
    super.initState();
    final initialCode = widget.participantCode ??
        (_tracker.participantCode.isNotEmpty && _tracker.participantCode != 'ANONIMO'
            ? _tracker.participantCode
            : '');
    _participantController = TextEditingController(text: initialCode);
    _testMode = widget.testMode ?? _tracker.testMode;
  }

  @override
  void dispose() {
    _participantController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  double _calculateCurrentScore() {
    int positives = (_answers[1]! - 1) +
        (_answers[3]! - 1) +
        (_answers[5]! - 1) +
        (_answers[7]! - 1) +
        (_answers[9]! - 1);
    int negatives = (5 - _answers[2]!) +
        (5 - _answers[4]!) +
        (5 - _answers[6]!) +
        (5 - _answers[8]!) +
        (5 - _answers[10]!);
    return (positives + negatives) * 2.5;
  }

  String _getAdjective(double score) {
    if (score >= 85.0) return 'Excelente (Grade A)';
    if (score >= 70.0) return 'Bueno (Grade B)';
    if (score >= 50.0) return 'Aceptable / Regular (Grade C)';
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
    setState(() => _isSubmitting = true);

    final score = _calculateCurrentScore();
    final adjective = _getAdjective(score);
    final participant = _participantController.text.trim().isEmpty
        ? 'ANONIMO'
        : _participantController.text.trim();

    _tracker.setParticipant(code: participant, testMode: _testMode);

    await _api.submitSusSurvey(
      sessionUuid: widget.sessionUuid ?? _tracker.sessionUuid,
      participantCode: participant,
      testMode: _testMode,
      q1: _answers[1]!,
      q2: _answers[2]!,
      q3: _answers[3]!,
      q4: _answers[4]!,
      q5: _answers[5]!,
      q6: _answers[6]!,
      q7: _answers[7]!,
      q8: _answers[8]!,
      q9: _answers[9]!,
      q10: _answers[10]!,
      comments: _commentsController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            const SizedBox(width: 8),
            Text(
              '¡Evaluación Guardada!',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Las respuestas del participante fueron registradas exitosamente.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getScoreColor(score).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _getScoreColor(score)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Puntaje SUS:',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${score.toStringAsFixed(1)} / 100 pts',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _getScoreColor(score),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Calificación: $adjective',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getScoreColor(score),
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
                'score': score,
                'adjective': adjective,
                'q1': _answers[1]!,
                'q2': _answers[2]!,
                'q3': _answers[3]!,
                'q4': _answers[4]!,
                'q5': _answers[5]!,
                'q6': _answers[6]!,
                'q7': _answers[7]!,
                'q8': _answers[8]!,
                'q9': _answers[9]!,
                'q10': _answers[10]!,
                'comments': _commentsController.text.trim(),
              });
            },
            child: Text(
              'Volver al Inicio',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentScore = _calculateCurrentScore();
    final adjective = _getAdjective(currentScore);

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
          'Encuesta de Usabilidad (SUS)',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera explicativa
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'INVESTIGACIÓN / TESIS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Escala SUS (Brooke, 1996)',
                          textAlign: TextAlign.end,
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Evaluación de Experiencia y Usabilidad',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Por favor, califique cada afirmación del 1 (Muy en desacuerdo) al 5 (Muy de acuerdo) según su interacción con el prototipo de compra.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tarjeta de Participante y Modo de Evaluación
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: const Icon(Icons.person, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Participante: ${_tracker.participantName.isNotEmpty ? _tracker.participantName : _participantController.text} (${_participantController.text})',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _testMode == 'posttest'
                              ? 'Evaluación: Post-test (Prototipo Cinemark)'
                              : 'Evaluación: Pre-test (App Oficial)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Preguntas 1 a 10
            ...List.generate(10, (index) {
              final qNum = index + 1;
              return _buildQuestionCard(qNum, _questions[index]);
            }),

            const SizedBox(height: 16),

            // Comentarios cualitativos opcionales
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comentarios u Observaciones Adicionales',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '¿Qué le pareció el proceso? ¿Hubo algo confuso o que facilitó su compra?',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Indicador de Puntuación SUS en Vivo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getScoreColor(currentScore).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _getScoreColor(currentScore)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Puntuación SUS Calculada:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          adjective,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(currentScore),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${currentScore.toStringAsFixed(1)} pts',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(currentScore),
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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _isSubmitting ? null : _submitSurvey,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Registrar Evaluación SUS',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int qNum, String questionText) {
    final selectedVal = _answers[qNum] ?? 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Escala Likert de 1 a 5
          Row(
            children: List.generate(5, (i) {
              final scoreVal = i + 1;
              final isSelected = selectedVal == scoreVal;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 4 ? 6.0 : 0.0),
                  child: InkWell(
                    onTap: () => setState(() => _answers[qNum] = scoreVal),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey[300]!,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$scoreVal',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            scoreVal == 1
                                ? 'Min'
                                : scoreVal == 5
                                    ? 'Max'
                                    : '',
                            style: GoogleFonts.inter(
                              fontSize: 9,
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
          ),
        ],
      ),
    );
  }
}
