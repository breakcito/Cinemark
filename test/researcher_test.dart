import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemark/views/researcher/pretest_observation_view.dart';
import 'package:cinemark/views/researcher/thesis_panel_view.dart';
import 'package:cinemark/core/telemetry/telemetry_tracker.dart';

void main() {
  group('Panel de Investigador y Ficha de Observación Pre-test (Tesis)', () {
    testWidgets('ThesisPanelView renderiza formulario de participante y acciones de tesis', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ThesisPanelView(),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar cabecera y botón para solicitar nueva evaluación
      expect(find.text('Panel de Evaluación'), findsOneWidget);
      expect(find.text('INICIAR NUEVA EVALUACIÓN'), findsOneWidget);

      // Pulsar para abrir formulario de forma explícita
      await tester.tap(find.text('INICIAR NUEVA EVALUACIÓN'));
      await tester.pumpAndSettle();

      // Verificar que el formulario aparece con código correlativo
      expect(find.text('Registrar Nuevo Participante'), findsOneWidget);
      expect(find.text('REGISTRAR Y COMENZAR EVALUACIÓN'), findsOneWidget);
      expect(find.text('P01'), findsOneWidget);
    });

    testWidgets('PretestObservationView permite cronometrar y registrar errores observados', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PretestObservationView(participantCode: 'P01'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ficha Pre-test: P01 (App Oficial)'), findsOneWidget);
      expect(find.text('TIEMPO TOTAL DE OBSERVACIÓN'), findsOneWidget);
      expect(find.text('INICIAR CRONÓMETRO'), findsOneWidget);

      // Iniciar cronómetro
      await tester.tap(find.text('INICIAR CRONÓMETRO'));
      await tester.pump();
      expect(find.text('PAUSAR'), findsOneWidget);

      // Registrar error predefinido de la etapa Inicio
      final errorChip = find.textContaining('Notificaciones');
      expect(errorChip, findsOneWidget);
      await tester.ensureVisible(errorChip);
      await tester.tap(errorChip);
      await tester.pumpAndSettle();

      // Debe haberse sumado 1 error
      expect(find.text('1 errores'), findsOneWidget);

      // Verificar selector de completitud
      expect(find.textContaining('Completó Compra'), findsOneWidget);
      expect(find.textContaining('Abandonó Compra'), findsOneWidget);
    });

    test('TelemetryTracker acumula toques (taps) y registra participante activo', () {
      final tracker = TelemetryTracker();
      tracker.setParticipant(code: 'P99', testMode: 'posttest');
      tracker.startSession(customSessionId: 'ses_test_p99');

      expect(tracker.participantCode, 'P99');
      expect(tracker.testMode, 'posttest');
      expect(tracker.sessionTapCount, 0);

      tracker.recordTap();
      tracker.recordTap();
      expect(tracker.sessionTapCount, 2);

      tracker.recordError('Seats', 'ERR_TEST', 'Error de prueba');
      expect(tracker.errorCount, 1);
    });
  });
}
