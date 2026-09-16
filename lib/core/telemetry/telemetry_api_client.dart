import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class TelemetryApiClient {
  static final TelemetryApiClient _instance = TelemetryApiClient._internal();
  factory TelemetryApiClient() => _instance;
  TelemetryApiClient._internal();

  String baseUrl = 'http://127.0.0.1:8000/api/v1';

  void setBaseUrl(String url) {
    baseUrl = url;
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

      if (res.statusCode == 201) {
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

      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[TelemetryApi] Error al enviar encuesta SUS: $e');
      return null;
    }
  }
}
