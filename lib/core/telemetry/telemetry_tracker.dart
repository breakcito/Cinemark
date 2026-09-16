import 'package:flutter/foundation.dart';
import 'telemetry_api_client.dart';

class TelemetryStep {
  final String stepName;
  final DateTime startTime;
  DateTime? endTime;
  int get durationInSeconds =>
      ((endTime ?? DateTime.now()).difference(startTime)).inSeconds;

  TelemetryStep({required this.stepName, required this.startTime});
}

class TelemetryTracker {
  static final TelemetryTracker _instance = TelemetryTracker._internal();
  factory TelemetryTracker() => _instance;
  TelemetryTracker._internal();

  final TelemetryApiClient _api = TelemetryApiClient();

  String _sessionUuid = '';
  String _participantCode = 'ANONIMO';
  String _testMode = 'posttest';
  String? _cinemaId;
  String? _cinemaName;
  String? _movieId;
  String? _movieTitle;

  DateTime? _sessionStartTime;
  final Map<String, TelemetryStep> _activeSteps = {};
  final List<TelemetryStep> _completedSteps = [];
  final List<Map<String, dynamic>> _errorEvents = [];

  String get sessionUuid => _sessionUuid;
  String get participantCode => _participantCode;
  String get testMode => _testMode;

  void setParticipant({
    required String code,
    String testMode = 'posttest',
  }) {
    _participantCode = code;
    _testMode = testMode;
  }

  void setContext({
    String? cinemaId,
    String? cinemaName,
    String? movieId,
    String? movieTitle,
  }) {
    if (cinemaId != null) _cinemaId = cinemaId;
    if (cinemaName != null) _cinemaName = cinemaName;
    if (movieId != null) _movieId = movieId;
    if (movieTitle != null) _movieTitle = movieTitle;
  }

  void startSession({String? customSessionId}) {
    _sessionUuid = customSessionId ??
        'ses_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
    _sessionStartTime = DateTime.now();
    _activeSteps.clear();
    _completedSteps.clear();
    _errorEvents.clear();
    debugPrint('[Telemetry] Sesión iniciada: $_sessionUuid a las $_sessionStartTime');

    // Sincronizar en segundo plano con la API
    _api.startSession(
      sessionUuid: _sessionUuid,
      participantCode: _participantCode,
      testMode: _testMode,
      cinemaId: _cinemaId,
      cinemaName: _cinemaName,
      movieId: _movieId,
      movieTitle: _movieTitle,
    );
  }

  void startStep(String stepName) {
    if (_sessionStartTime == null) {
      startSession();
    }
    _activeSteps[stepName] = TelemetryStep(
      stepName: stepName,
      startTime: DateTime.now(),
    );
    debugPrint('[Telemetry] Iniciando etapa: $stepName');
  }

  void completeStep(String stepName) {
    final step = _activeSteps.remove(stepName);
    if (step != null) {
      step.endTime = DateTime.now();
      _completedSteps.add(step);
      debugPrint(
        '[Telemetry] Etapa completada: $stepName en ${step.durationInSeconds}s',
      );

      // Enviar duración del paso a la API en segundo plano
      if (_sessionUuid.isNotEmpty) {
        _api.recordStepDuration(
          sessionUuid: _sessionUuid,
          stepName: stepName,
          durationSeconds: step.durationInSeconds.toDouble(),
          startedAt: step.startTime,
          endedAt: step.endTime,
        );
      }
    }
  }

  void recordError(String stepName, String errorType, String description) {
    final error = {
      'step': stepName,
      'errorType': errorType,
      'description': description,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _errorEvents.add(error);
    debugPrint('[Telemetry ERROR] En $stepName: $errorType - $description');

    // Enviar error a la API
    if (_sessionUuid.isNotEmpty) {
      _api.recordError(
        sessionUuid: _sessionUuid,
        stepName: stepName,
        errorType: errorType,
        description: description,
      );
    }
  }

  void finishSession({
    required bool isCompleted,
    required String maxStepReached,
  }) {
    final duration = totalDurationSeconds.toDouble();
    if (_sessionUuid.isNotEmpty) {
      _api.completeSession(
        sessionUuid: _sessionUuid,
        isCompleted: isCompleted,
        maxStepReached: maxStepReached,
        totalDurationSeconds: duration,
      );
    }
  }

  int get totalDurationSeconds {
    if (_sessionStartTime == null) return 0;
    return DateTime.now().difference(_sessionStartTime!).inSeconds;
  }

  int get errorCount => _errorEvents.length;

  Map<String, dynamic> getSummaryReport() {
    final stepTimes = <String, int>{};
    for (final step in _completedSteps) {
      stepTimes[step.stepName] = step.durationInSeconds;
    }

    return {
      'sessionUuid': _sessionUuid,
      'participantCode': _participantCode,
      'testMode': _testMode,
      'totalDurationSeconds': totalDurationSeconds,
      'errorCount': errorCount,
      'steps': stepTimes,
      'errors': _errorEvents,
      'completed': true,
    };
  }
}
