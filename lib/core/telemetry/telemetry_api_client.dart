import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class TelemetryApiClient {
  static final TelemetryApiClient _instance = TelemetryApiClient._internal();
  factory TelemetryApiClient() => _instance;
  TelemetryApiClient._internal() {
    initFromEnv();
  }

  String baseUrl = 'http://127.0.0.1:8000/api/v1';
  final List<String> candidateUrls = [];

  void initFromEnv() {
    String? envUrl;
    try {
      if (dotenv.isInitialized) {
        envUrl = dotenv.env['API_BASE_URL'];
      }
    } catch (_) {}

    const defineUrl = String.fromEnvironment('API_BASE_URL');

    if (envUrl != null && envUrl.trim().isNotEmpty) {
      baseUrl = envUrl.trim();
    } else if (defineUrl.isNotEmpty) {
      baseUrl = defineUrl.trim();
    } else {
      baseUrl = 'http://127.0.0.1:8000/api/v1';
    }

    candidateUrls.clear();
    final defaults = [
      baseUrl,
      'http://127.0.0.1:8000/api/v1',
      'http://192.168.100.36:8000/api/v1',
      'http://10.0.2.2:8000/api/v1',
    ];
    for (final u in defaults) {
      if (!candidateUrls.contains(u)) candidateUrls.add(u);
    }
  }

  void setBaseUrl(String url) {
    baseUrl = url.trim();
  }

  String get wsUrl {
    final clean = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    return '$clean/telemetry/ws';
  }

  /// Realiza peticiones POST con reintentos automáticos para evitar fallas por caídas momentáneas de red
  Future<http.Response?> _postWithRetry(
    Uri uri, {
    required Map<String, dynamic> body,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final res = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(timeout);
        return res;
      } catch (e) {
        debugPrint('[TelemetryApiClient] POST intento $attempts falló para $uri: $e');
        if (attempts >= maxRetries) return null;
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      }
    }
    return null;
  }

  /// Realiza peticiones GET con reintentos automáticos
  Future<http.Response?> _getWithRetry(
    Uri uri, {
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final res = await http.get(uri).timeout(timeout);
        return res;
      } catch (e) {
        debugPrint('[TelemetryApiClient] GET intento $attempts falló para $uri: $e');
        if (attempts >= maxRetries) return null;
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      }
    }
    return null;
  }

  /// Verifica el estado de conexión con el backend API sin alternar arbitrariamente la URL
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final stopwatch = Stopwatch()..start();
      final uri = Uri.parse('$baseUrl/telemetry/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['status'] == 'connected') {
          return {
            'connected': true,
            'endpoint': baseUrl,
            'latencyMs': stopwatch.elapsedMilliseconds,
          };
        }
      }
    } catch (_) {}

    return {
      'connected': false,
      'endpoint': baseUrl,
      'error': 'No se pudo contactar al servidor en $baseUrl',
    };
  }

  Future<bool> syncFullSession({
    required String sessionUuid,
    String participantCode = 'ANONIMO',
    String testMode = 'posttest',
    String? cinemaId,
    String? cinemaName,
    String? movieId,
    String? movieTitle,
    required DateTime startedAt,
    DateTime? endedAt,
    required double totalDurationSeconds,
    int tapsCount = 0,
    bool isCompleted = true,
    String maxStepReached = 'Pago',
    String? deviceInfo,
    List<Map<String, dynamic>> steps = const [],
    List<Map<String, dynamic>> errors = const [],
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/telemetry/session/sync');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_uuid': sessionUuid,
              'participant_code': participantCode,
              'test_mode': testMode,
              'cinema_id': cinemaId ?? AppConstants.defaultCinemaId,
              'cinema_name': cinemaName ?? AppConstants.defaultCinemaName,
              'movie_id': movieId,
              'movie_title': movieTitle,
              'started_at': startedAt.toIso8601String(),
              'ended_at': (endedAt ?? DateTime.now()).toIso8601String(),
              'total_duration_seconds': totalDurationSeconds,
              'taps_count': tapsCount,
              'is_completed': isCompleted,
              'max_step_reached': maxStepReached,
              'device_info': deviceInfo ?? 'Flutter Client Mobile',
              'steps': steps,
              'errors': errors,
            }),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[TelemetryApi] Error al sincronizar sesión completa: $e');
      return false;
    }
  }

  Future<bool> startSession({
    required String sessionUuid,
    String participantCode = 'ANONIMO',
    String testMode = 'posttest',
    String? cinemaId,
    String? cinemaName,
    String? movieId,
    String? movieTitle,
    String? deviceInfo,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/telemetry/session/start');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_uuid': sessionUuid,
              'participant_code': participantCode,
              'test_mode': testMode,
              'cinema_id': cinemaId ?? AppConstants.defaultCinemaId,
              'cinema_name': cinemaName ?? AppConstants.defaultCinemaName,
              'movie_id': movieId,
              'movie_title': movieTitle,
              'device_info': deviceInfo ?? 'Flutter Client',
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        debugPrint('[TelemetryApi] Sesión iniciada en servidor: $sessionUuid');
        return true;
      } else {
        debugPrint('[TelemetryApi] Error status: ${res.statusCode} ${res.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[TelemetryApi] Error de red al iniciar sesión: $e');
      return false;
    }
  }

  Future<bool> recordStepDuration({
    required String sessionUuid,
    required String stepName,
    required double durationSeconds,
    int tapsCount = 0,
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/telemetry/session/step');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_uuid': sessionUuid,
              'step_name': stepName,
              'duration_seconds': durationSeconds,
              'taps_count': tapsCount,
              'started_at': startedAt?.toIso8601String(),
              'ended_at': (endedAt ?? DateTime.now()).toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 4));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[TelemetryApi] Error al registrar duración de etapa: $e');
      return false;
    }
  }

  Future<bool> recordError({
    required String sessionUuid,
    required String stepName,
    required String errorType,
    String? description,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/telemetry/session/error');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_uuid': sessionUuid,
              'step_name': stepName,
              'error_type': errorType,
              'description': description,
              'occurred_at': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 4));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[TelemetryApi] Error al registrar incidencia: $e');
      return false;
    }
  }

  Future<bool> completeSession({
    required String sessionUuid,
    required bool isCompleted,
    required String maxStepReached,
    required double totalDurationSeconds,
    int tapsCount = 0,
    String? participantCode,
    int? totalErrors,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/telemetry/session/complete');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_uuid': sessionUuid,
              'is_completed': isCompleted,
              'max_step_reached': maxStepReached,
              'total_duration_seconds': totalDurationSeconds,
              'taps_count': tapsCount,
              'participant_code': participantCode,
              'total_errors': totalErrors,
              'ended_at': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 4));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[TelemetryApi] Error al finalizar sesión: $e');
      return false;
    }
  }

  Future<bool> registerParticipant({
    required String participantCode,
    String? name,
    int? age,
    String? gender,
    String? cinemaFrequency,
    String? notes,
  }) async {
    final uri = Uri.parse('$baseUrl/telemetry/participant');
    final res = await _postWithRetry(
      uri,
      body: {
        'participant_code': participantCode,
        'name': name,
        'age': age,
        'gender': gender,
        'cinema_frequency': cinemaFrequency,
        'notes': notes,
      },
    );
    return res != null && res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<List<Map<String, dynamic>>> getParticipants() async {
    final uri = Uri.parse('$baseUrl/telemetry/participants');
    final res = await _getWithRetry(uri);
    if (res != null && res.statusCode == 200) {
      try {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    return [];
  }

  Future<bool> activateParticipant(String participantCode) async {
    final uri = Uri.parse('$baseUrl/telemetry/participant/activate');
    final res = await _postWithRetry(
      uri,
      body: {'participant_code': participantCode},
    );
    return res != null && res.statusCode == 200;
  }

  Future<bool> clearActiveParticipant() async {
    final uri = Uri.parse('$baseUrl/telemetry/participant/clear');
    final res = await _postWithRetry(uri, body: {});
    return res != null && res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> getActiveParticipant() async {
    final uri = Uri.parse('$baseUrl/telemetry/participant/active');
    final res = await _getWithRetry(uri);
    if (res != null && res.statusCode == 200) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['active'] == true && data['participant'] != null) {
          return Map<String, dynamic>.from(data['participant']);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> getObservationSheet(
    String participantCode, {
    String testMode = 'pretest',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/telemetry/observation/$participantCode?test_mode=$testMode',
    );
    final res = await _getWithRetry(uri, timeout: const Duration(seconds: 15));
    if (res != null && res.statusCode == 200) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> recordPretestObservation({
    required String participantCode,
    String testMode = 'pretest',
    String? cinemaName,
    String? movieTitle,
    required double totalDurationSeconds,
    bool isCompleted = true,
    String maxStepReached = 'Historial',
    int totalErrors = 0,
    int tapsCount = 0,
    Map<String, double>? stepDurations,
    List<Map<String, dynamic>>? errors,
    Map<String, dynamic>? susSurvey,
    String? notes,
  }) async {
    final uri = Uri.parse('$baseUrl/telemetry/pretest-observation');
    final res = await _postWithRetry(
      uri,
      body: {
        'participant_code': participantCode,
        'test_mode': testMode,
        'cinema_name': cinemaName ??
            (testMode == 'pretest'
                ? 'Cinemark Mallplaza Trujillo (App Oficial)'
                : 'Cinemark Prototipo Mejorado'),
        'movie_title': movieTitle ??
            (testMode == 'pretest'
                ? 'Evaluación App Oficial'
                : 'Evaluación Prototipo'),
        'total_duration_seconds': totalDurationSeconds,
        'is_completed': isCompleted,
        'max_step_reached': maxStepReached,
        'total_errors': totalErrors,
        'taps_count': tapsCount,
        'step_durations': stepDurations,
        'errors': errors,
        'sus_survey': susSurvey,
        'notes': notes,
      },
      maxRetries: 3,
      timeout: const Duration(seconds: 15),
    );

    if (res != null && res.statusCode >= 200 && res.statusCode < 300) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> getWilcoxonMatrix() async {
    try {
      final uri = Uri.parse('$baseUrl/analytics/wilcoxon-matrix');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[TelemetryApi] Error al obtener matriz de Wilcoxon: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> submitSusSurvey({
    String? sessionUuid,
    String participantCode = 'ANONIMO',
    String testMode = 'posttest',
    required int q1,
    required int q2,
    required int q3,
    required int q4,
    required int q5,
    required int q6,
    required int q7,
    required int q8,
    required int q9,
    required int q10,
    String? comments,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/survey/sus');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_uuid': sessionUuid,
              'participant_code': participantCode,
              'test_mode': testMode,
              'q1': q1,
              'q2': q2,
              'q3': q3,
              'q4': q4,
              'q5': q5,
              'q6': q6,
              'q7': q7,
              'q8': q8,
              'q9': q9,
              'q10': q10,
              'comments': comments,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[TelemetryApi] Error al enviar encuesta SUS: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> submitComparativeSurvey({
    required String participantCode,
    required Map<int, int> preAnswers,
    required Map<int, int> postAnswers,
    int heuristicErrorPre = 3,
    int heuristicErrorPost = 5,
    int heuristicSeatsPre = 3,
    int heuristicSeatsPost = 5,
    int heuristicTimerPre = 2,
    int heuristicTimerPost = 5,
    String preferredSystem = 'Prototipo',
    String? comments,
  }) async {
    final uri = Uri.parse('$baseUrl/survey/comparative');
    final res = await _postWithRetry(
      uri,
      body: {
        'participant_code': participantCode,
        'pre_q1': preAnswers[1] ?? 3,
        'pre_q2': preAnswers[2] ?? 3,
        'pre_q3': preAnswers[3] ?? 3,
        'pre_q4': preAnswers[4] ?? 3,
        'pre_q5': preAnswers[5] ?? 3,
        'pre_q6': preAnswers[6] ?? 3,
        'pre_q7': preAnswers[7] ?? 3,
        'pre_q8': preAnswers[8] ?? 3,
        'pre_q9': preAnswers[9] ?? 3,
        'pre_q10': preAnswers[10] ?? 3,
        'post_q1': postAnswers[1] ?? 5,
        'post_q2': postAnswers[2] ?? 1,
        'post_q3': postAnswers[3] ?? 5,
        'post_q4': postAnswers[4] ?? 1,
        'post_q5': postAnswers[5] ?? 5,
        'post_q6': postAnswers[6] ?? 1,
        'post_q7': postAnswers[7] ?? 5,
        'post_q8': postAnswers[8] ?? 1,
        'post_q9': postAnswers[9] ?? 5,
        'post_q10': postAnswers[10] ?? 1,
        'heuristic_error_pre': heuristicErrorPre,
        'heuristic_error_post': heuristicErrorPost,
        'heuristic_seats_pre': heuristicSeatsPre,
        'heuristic_seats_post': heuristicSeatsPost,
        'heuristic_timer_pre': heuristicTimerPre,
        'heuristic_timer_post': heuristicTimerPost,
        'preferred_system': preferredSystem,
        'comments': comments,
      },
      maxRetries: 3,
      timeout: const Duration(seconds: 15),
    );

    if (res != null && res.statusCode >= 200 && res.statusCode < 300) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }
}
