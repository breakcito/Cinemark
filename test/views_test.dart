import 'package:cinemark/core/constants/app_constants.dart';
import 'package:cinemark/core/telemetry/telemetry_tracker.dart';
import 'package:cinemark/data/mock_data.dart';
import 'package:cinemark/data/models/purchase_session.dart';
import 'package:cinemark/views/1_splash/splash_view.dart';
import 'package:cinemark/views/2_home/home_view.dart';
import 'package:cinemark/views/3_showtimes/showtimes_view.dart';
import 'package:cinemark/views/4_tickets/tickets_view.dart';
import 'package:cinemark/views/11_survey/sus_survey_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    PurchaseSession().stopTimer();
    PurchaseSession().resetSession();
  });

  tearDown(() {
    PurchaseSession().stopTimer();
  });

  group('1. Vista de Apertura (SplashView)', () {
    testWidgets('Muestra branding oficial e inicializa sesión de compra',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: SplashView()),
      );

      expect(find.byType(Hero), findsOneWidget);
      expect(PurchaseSession().selectedCinema, isNotNull);
      expect(
        PurchaseSession().selectedCinema!.name,
        AppConstants.defaultCinemaName,
      );

      // Esperar timer de splash
      await tester.pump(const Duration(milliseconds: 1900));
    });
  });

  group('2. Vista de Inicio (HomeView)', () {
    testWidgets(
        'Renderiza saludo, selector de cine, cartelera y banner de notificaciones',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      PurchaseSession().setCinema(MockData.cinemas.first);

      await tester.pumpWidget(
        const MaterialApp(home: HomeView()),
      );
      await tester.pump();

      // Saludo
      expect(
        find.text('HOLA, ${AppConstants.defaultUserName.toUpperCase()}!'),
        findsOneWidget,
      );
      expect(find.text('CARTELERA POR CINE'), findsOneWidget);

      // Banner no intrusivo de notificación
      expect(find.text('Activa tus recordatorios'), findsOneWidget);
      expect(find.text('Ahora no'), findsOneWidget);

      // Descartar banner
      await tester.tap(find.text('Ahora no'));
      await tester.pump();
      expect(find.text('Activa tus recordatorios'), findsNothing);

      // Secciones
      expect(find.text('DESTACADOS'), findsOneWidget);
      expect(find.text('CARTELERA'), findsOneWidget);
      expect(
        find.text('Mostrar solo con funciones en Trujillo'),
        findsOneWidget,
      );
    });
  });

  group('3. Vista de Horarios (ShowtimesView)', () {
    testWidgets('Muestra temporizador visible y horas de función',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final movie = MockData.getMovies().first; // Spider-Man
      PurchaseSession().setCinema(MockData.cinemas.first);

      await tester.pumpWidget(
        MaterialApp(home: ShowtimesView(movie: movie)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.text('SPIDER MAN UN NUEVO DIA'), findsOneWidget);
      expect(find.text('Ver trailer'), findsOneWidget);
      expect(find.text('Ver sinopsis'), findsOneWidget);

      // Horarios disponibles
      expect(find.text('13:10'), findsOneWidget);
      expect(find.text('16:20'), findsOneWidget);
      expect(find.text('19:20'), findsOneWidget);

      // Heurística #5: Horario agotado renderizado con tag Agotado
      expect(find.text('Agotado'), findsOneWidget);

      PurchaseSession().stopTimer();
    });
  });

  group('4. Vista de Tickets (TicketsView)', () {
    testWidgets('Permite seleccionar tarifas y valida botón continuar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final movie = MockData.getMovies().first;
      final showtime = movie.showtimes.first;
      PurchaseSession().setCinema(MockData.cinemas.first);
      PurchaseSession().selectShowtime(showtime);

      await tester.pumpWidget(
        MaterialApp(home: TicketsView(movie: movie, showtime: showtime)),
      );
      await tester.pump();

      // Pestañas
      expect(find.text('TARIFAS'), findsOneWidget);
      expect(find.text('CANJEA TU CÓDIGO'), findsOneWidget);

      // Carrito inicialmente en 0
      expect(find.text('0 entradas seleccionadas'), findsOneWidget);

      // Aumentar 1 entrada con el botón '+'
      final addButtons = find.byIcon(Icons.add);
      expect(addButtons, findsWidgets);

      await tester.tap(addButtons.first);
      await tester.pump();

      // Carrito actualizado
      expect(PurchaseSession().totalTicketCount, 1);
      expect(find.text('1 entrada'), findsOneWidget);

      PurchaseSession().stopTimer();
    });

    testWidgets(
        'Canjea cupones por lote (Batch 3x) y permite quitar entradas individuales',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final movie = MockData.getMovies().first;
      final showtime = movie.showtimes.first;
      PurchaseSession().setCinema(MockData.cinemas.first);
      PurchaseSession().selectShowtime(showtime);

      await tester.pumpWidget(
        MaterialApp(home: TicketsView(movie: movie, showtime: showtime)),
      );
      await tester.pump();

      PurchaseSession().stopTimer();
      // Cambiar a pestaña CANJEA TU CÓDIGO
      await tester.tap(find.text('CANJEA TU CÓDIGO'));
      await tester.pumpAndSettle();

      // Usar chip de prueba rápida Pack 3x
      final packChip = find.text('Pack 3x (PACK3X)');
      expect(packChip, findsOneWidget);
      await tester.tap(packChip);
      await tester.pumpAndSettle();

      // Se deben haber generado 3 entradas
      expect(PurchaseSession().totalRedeemedTickets, 3);
      expect(PurchaseSession().totalTicketCount, 3);
      expect(find.text('3 entradas activas'), findsOneWidget);

      // Remover 1 de las entradas del lote (Heurística #3 Control del usuario)
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsNWidgets(3));
      await tester.tap(deleteButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Ahora quedan 2 entradas
      expect(PurchaseSession().totalRedeemedTickets, 2);
      expect(PurchaseSession().totalTicketCount, 2);
      expect(find.text('2 entradas activas'), findsOneWidget);

      PurchaseSession().stopTimer();
    });
  });

  group('5. Métricas de Telemetría (Tesis Indicadores V.D)', () {
    test('Registra etapas, tiempos y errores adecuadamente', () {
      final tracker = TelemetryTracker();
      tracker.startSession();
      tracker.startStep('Horarios');
      tracker.recordError(
          'Horarios', 'Agotado', 'Intento de clic en función agotada');
      tracker.completeStep('Horarios');

      final summary = tracker.getSummaryReport();
      expect(summary['completed'], isTrue);
      expect(summary['errorCount'], 1);
      expect((summary['steps'] as Map).containsKey('Horarios'), isTrue);
    });
  });

  group('6. Vista de Encuesta SUS (Satisfacción del Usuario)', () {
    testWidgets('Renderiza los 10 ítems Likert y calcula puntaje en tiempo real',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: SusSurveyView(sessionUuid: 'test-session-123')),
      );
      await tester.pumpAndSettle();

      // Cabecera y datos
      expect(find.text('Encuesta de Usabilidad (SUS)'), findsOneWidget);
      expect(find.text('INVESTIGACIÓN / TESIS'), findsOneWidget);
      expect(find.text('Código de Participante'), findsOneWidget);

      // Debe contener preguntas clave
      expect(find.text('Me gustaría usar esta aplicación de cine con frecuencia.'), findsOneWidget);
      expect(find.text('Encontré la aplicación innecesariamente compleja.'), findsOneWidget);

      // Botón de registro presente
      expect(find.text('Registrar Evaluación SUS'), findsOneWidget);

      // Puntaje calculado visible (inicialmente preconfigurado en 97.5 o > 85 pts)
      expect(find.textContaining('pts'), findsWidgets);
    });
  });
}
