import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

class TelemetryTracker extends ChangeNotifier {
  static final TelemetryTracker _instance = TelemetryTracker._internal();
  factory TelemetryTracker() => _instance;
  TelemetryTracker._internal();

  final TelemetryApiClient _api = TelemetryApiClient();

  String _sessionUuid = '';
  String _participantCode = 'ANONIMO';
  String _participantName = '';
  String _testMode = 'posttest';
  String? _cinemaId;
  String? _cinemaName;
  String? _movieId;
  String? _movieTitle;

  DateTime? _sessionStartTime;
  int _sessionTapCount = 0;
  int _currentStepTapCount = 0;
  final Map<String, TelemetryStep> _activeSteps = {};
  final List<TelemetryStep> _completedSteps = [];
  final List<Map<String, dynamic>> _errorEvents = [];

  List<Map<String, dynamic>> _savedParticipants = [];
  bool _hasLoadedParticipants = false;
  bool _isSyncing = false;

  String get sessionUuid => _sessionUuid;
  String get participantCode => _participantCode;
  String get participantName => _participantName;
  String get testMode => _testMode;
  int get sessionTapCount => _sessionTapCount;
  bool get hasActiveParticipant =>
      _participantCode.isNotEmpty && _participantCode != 'ANONIMO';
  List<Map<String, dynamic>> get savedParticipants => _savedParticipants;
  bool get hasLoadedParticipants => _hasLoadedParticipants;
  bool get isSyncing => _isSyncing;

  WebSocket? _ws;
  bool _isConnectingWs = false;

  /// Inicia conexión WebSocket en tiempo real para sincronización sin sondeo (polling)
  void startLiveParticipantSync() {
    syncActiveParticipantFromServer();
    refreshParticipants(silent: true);
    connectWebSocket();
  }

  void stopLiveParticipantSync() {
    _ws?.close();
    _ws = null;
  }

  /// Conecta al canal WebSocket de la API para recibir eventos push instantáneos
  Future<void> connectWebSocket() async {
    if (_isConnectingWs || _ws != null) return;
    _isConnectingWs = true;

    try {
      final wsUri = Uri.parse(_api.wsUrl);
      final socket = await WebSocket.connect(wsUri.toString()).timeout(
        const Duration(seconds: 4),
      );
      _ws = socket;
      _isConnectingWs = false;
      debugPrint('[TelemetryTracker] WebSocket conectado a $wsUri');

      _ws!.listen(
        (data) {
          try {
            final msg = jsonDecode(data.toString()) as Map<String, dynamic>;
            _handleWebSocketEvent(msg);
          } catch (e) {
            debugPrint('[TelemetryTracker] Error al procesar mensaje WS: $e');
          }
        },
        onError: (err) {
          debugPrint('[TelemetryTracker] Error en WebSocket: $err');
          _scheduleWebSocketReconnect();
        },
        onDone: () {
          debugPrint('[TelemetryTracker] WebSocket cerrado por servidor');
          _scheduleWebSocketReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isConnectingWs = false;
      _scheduleWebSocketReconnect();
    }
  }

  void _scheduleWebSocketReconnect() {
    _ws = null;
    // Reintentar conexión con pausa prudencial de 10s, sin saturar la red
    Future.delayed(const Duration(seconds: 10), () {
      if (_ws == null) {
        connectWebSocket();
      }
    });
  }

  void _handleWebSocketEvent(Map<String, dynamic> msg) {
    final event = msg['event'];
    if (event == 'initial_state') {
      final p = msg['active_participant'] as Map<String, dynamic>?;
      if (p != null) {
        final code = p['participant_code']?.toString() ?? '';
        final name = p['name']?.toString() ?? 'Participante $code';
        if (code.isNotEmpty) {
          setParticipant(code: code, name: name, testMode: 'posttest');
        }
      } else {
        clearParticipant();
      }
      refreshParticipants(silent: true);
    } else if (event == 'participant_activated') {
      final p = msg['participant'] as Map<String, dynamic>?;
      if (p != null) {
        final code = p['participant_code']?.toString() ?? '';
        final name = p['name']?.toString() ?? 'Participante $code';
        if (code.isNotEmpty) {
          setParticipant(code: code, name: name, testMode: 'posttest');
        }
      }
      refreshParticipants(silent: true);
    } else if (event == 'participant_cleared') {
      clearParticipant();
      refreshParticipants(silent: true);
    } else if (event == 'observation_saved' || event == 'survey_saved') {
      refreshParticipants(silent: true);
    }
    notifyListeners();
  }

  /// Refresca la lista de participantes desde la API guardándola en caché en memoria
  Future<void> refreshParticipants({bool silent = false}) async {
    if (!silent) {
      _isSyncing = true;
      notifyListeners();
    }
    try {
      final list = await _api.getParticipants();
      _savedParticipants = list;
      _hasLoadedParticipants = true;
    } catch (e) {
      debugPrint('[TelemetryTracker] Error refrescando participantes: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Sincronización puntual on-demand (sin bucles de sondeo repetitivo)
  Future<void> syncActiveParticipantFromServer() async {
    try {
      final res = await _api.getActiveParticipant();
      if (res != null) {
        final code = res['participant_code']?.toString() ?? '';
        final name = res['name']?.toString() ?? 'Participante $code';
        if (code.isNotEmpty) {
          setParticipant(
            code: code,
            name: name,
            testMode: 'posttest',
          );
        }
      } else {
        clearParticipant();
      }
    } catch (e) {
      // Ignorar fallas momentáneas de red
    }
  }

  void clearParticipant() {
    _participantCode = 'ANONIMO';
    _participantName = '';
    _sessionUuid = '';
    _sessionTapCount = 0;
    _errorEvents.clear();
    _activeSteps.clear();
    _completedSteps.clear();
    notifyListeners();
  }

  void recordTap() {
    _sessionTapCount++;
    _currentStepTapCount++;
  }

  void setParticipant({
    required String code,
    String? name,
    String testMode = 'posttest',
  }) {
    _participantCode = code;
    if (name != null && name.isNotEmpty) {
      _participantName = name;
    }
    _testMode = testMode;
    notifyListeners();
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
    _sessionTapCount = 0;
    _currentStepTapCount = 0;
    _activeSteps.clear();
    _completedSteps.clear();
    _errorEvents.clear();
    debugPrint('[Telemetry] Sesión iniciada: $_sessionUuid a las $_sessionStartTime');
  }

  void startStep(String stepName) {
    if (_sessionStartTime == null) {
      startSession();
    }
    _currentStepTapCount = 0;
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
      final stepTaps = _currentStepTapCount;
      _currentStepTapCount = 0;
      debugPrint(
        '[Telemetry] Etapa completada: $stepName en ${step.durationInSeconds}s ($stepTaps toques)',
      );
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
  }

  void finishSession({
    required bool isCompleted,
    required String maxStepReached,
  }) {
    debugPrint('[Telemetry] Sesión finalizada: completada=$isCompleted, paso=$maxStepReached');
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

  Future<bool> syncWithServer({
    String maxStepReached = 'En progreso',
    bool isCompleted = false,
  }) async {
    if (_sessionUuid.isEmpty) return false;

    final stepsPayload = _completedSteps
        .map((s) => {
              'session_uuid': _sessionUuid,
              'step_name': s.stepName,
              'duration_seconds': s.durationInSeconds.toDouble(),
              'started_at': s.startTime.toIso8601String(),
              'ended_at': (s.endTime ?? DateTime.now()).toIso8601String(),
            })
        .toList();

    return await _api.syncFullSession(
      sessionUuid: _sessionUuid,
      participantCode: _participantCode,
      testMode: _testMode,
      cinemaId: _cinemaId,
      cinemaName: _cinemaName,
      movieId: _movieId,
      movieTitle: _movieTitle,
      startedAt: _sessionStartTime ?? DateTime.now(),
      endedAt: DateTime.now(),
      totalDurationSeconds: totalDurationSeconds.toDouble(),
      tapsCount: _sessionTapCount,
      isCompleted: isCompleted,
      maxStepReached: maxStepReached,
      steps: stepsPayload,
      errors: _errorEvents,
    );
  }
}

