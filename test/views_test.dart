import 'package:cinemark/core/constants/app_constants.dart';
import 'package:cinemark/core/telemetry/telemetry_tracker.dart';
import 'package:cinemark/data/mock_data.dart';
import 'package:cinemark/data/models/purchase_session.dart';
import 'package:cinemark/views/1_splash/splash_view.dart';
import 'package:cinemark/views/2_home/home_view.dart';
import 'package:cinemark/views/3_showtimes/showtimes_view.dart';
import 'package:cinemark/views/4_tickets/tickets_view.dart';
import 'package:cinemark/views/5_seats/seats_view.dart';
import 'package:cinemark/views/6_concessions/concessions_view.dart';
import 'package:cinemark/views/7_payment/payment_view.dart';
import 'package:cinemark/views/8_ticket_confirmation/ticket_confirmation_view.dart';
import 'package:cinemark/views/9_history/purchase_history_view.dart';
import 'package:cinemark/views/10_upcoming_ticket/widgets/upcoming_ticket_card.dart';
import 'package:cinemark/views/11_survey/sus_survey_view.dart';
import 'package:cinemark/data/models/completed_order_model.dart';
import 'package:cinemark/data/purchase_history_manager.dart';
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
      expect(find.textContaining('Participante'), findsWidgets);

      // Debe contener preguntas clave
      expect(find.text('Me gustaría usar esta aplicación de cine con frecuencia.'), findsOneWidget);
      expect(find.text('Encontré la aplicación innecesariamente compleja.'), findsOneWidget);

      // Botón de registro presente
      expect(find.text('Registrar Evaluación SUS'), findsOneWidget);

      // Puntaje calculado visible (inicialmente preconfigurado en 97.5 o > 85 pts)
      expect(find.textContaining('pts'), findsWidgets);
    });
  });

  group('7. Vista de Asientos (SeatsView)', () {
    testWidgets('Renderiza pantalla, controles de zoom, leyenda y permite seleccionar butacas',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final movie = MockData.getMovies().first;
      final showtime = movie.showtimes.first;
      PurchaseSession().updateTicketQuantity('t-general-2d', 2);

      await tester.pumpWidget(
        MaterialApp(home: SeatsView(movie: movie, showtime: showtime)),
      );
      await tester.pumpAndSettle();

      // Cabecera y representación del mundo real
      expect(find.text('Elige tus Asientos'), findsOneWidget);
      expect(find.text('PANTALLA'), findsOneWidget);

      // Leyenda (Heurística #6)
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('Tu selección'), findsOneWidget);
      expect(find.text('Ocupado'), findsOneWidget);

      // Controles de zoom rápido accesibles (Heurística de usabilidad explícita)
      expect(find.byIcon(Icons.add), findsWidgets);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);

      // Estado de selección inicial
      expect(find.text('Butacas: 0 de 2 seleccionadas'), findsOneWidget);
      expect(find.text('SELECCIONA TUS BUTACAS'), findsOneWidget);

      PurchaseSession().stopTimer();
    });
  });

  group('8. Vista de Confitería (ConcessionsView)', () {
    testWidgets('Muestra combos populares primero, buscador en vivo y membresía in-flow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: ConcessionsView()),
      );
      await tester.pumpAndSettle();

      // Título y buscador
      expect(find.text('Snacks & Confitería'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Combos populares priorizados primero
      expect(find.text('Combos Populares'), findsWidgets);
      expect(find.text('Combo 1: Dúo Clásico'), findsOneWidget);

      // Banner de membresía in-flow (sin retroceder de la compra)
      expect(find.text('¿Aún no eres socio Cinemark Club?'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Botón claro para continuar con o sin snacks (Libertad del usuario)
      expect(find.text('CONTINUAR SIN CONFITERÍA'), findsOneWidget);

      PurchaseSession().stopTimer();
    });
  });

  group('9. Vista de Pago (PaymentView)', () {
    testWidgets('Renderiza auto-rellenado de datos, opciones de tarjeta y Yape, y comprobante',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final movie = MockData.getMovies().first;
      final showtime = movie.showtimes.first;
      final cinema = MockData.cinemas.first;

      PurchaseSession().setCinema(cinema);
      PurchaseSession().selectMovie(movie);
      PurchaseSession().selectShowtime(showtime);
      PurchaseSession().updateTicketQuantity('t-general-2d', 2);
      PurchaseSession().toggleSeat('F5', maxAllowed: 2);
      PurchaseSession().toggleSeat('F6', maxAllowed: 2);

      await tester.pumpWidget(
        const MaterialApp(home: PaymentView()),
      );
      await tester.pumpAndSettle();

      // Cabecera y estado
      expect(find.text('PAGO Y CONFIRMACIÓN'), findsOneWidget);
      expect(find.text('Datos del Comprador'), findsOneWidget);

      // Métodos de pago (Tarjeta y Yape)
      expect(find.text('Tarjeta Débito / Crédito'), findsOneWidget);
      expect(find.text('Pagar con Yape'), findsOneWidget);

      // Comprobantes
      expect(find.text('Boleta Electrónica'), findsOneWidget);
      expect(find.text('Factura (RUC)'), findsOneWidget);

      // Botón de pago con monto total visible
      expect(find.textContaining('PAGAR S/'), findsOneWidget);

      PurchaseSession().stopTimer();
    });
  });

  group('10. Vista de Boleto Digital (TicketConfirmationView)', () {
    testWidgets('Renderiza estilo Boarding Pass con QR, sala, butacas y CTA de encuesta',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final order = CompletedOrder(
        orderCode: 'CNK-829410',
        purchaseDate: DateTime.now(),
        movieTitle: 'Spider-Man: Beyond the Spider-Verse',
        moviePosterUrl: 'https://image.tmdb.org/t/p/w500/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg',
        movieClassification: 'TE+7',
        movieDuration: '140 min',
        cinemaName: 'Cinemark Mallplaza Trujillo',
        cinemaAddress: 'Av. América Oeste 750',
        showtimeDate: DateTime.now(),
        showtimeHour: '19:20',
        roomName: 'Sala XD 1',
        format: 'XD 2D',
        language: 'Doblada',
        seats: ['F5', 'F6'],
        tickets: [
          const OrderTicketItem(name: 'General 2D', quantity: 2, unitPrice: 16.0),
        ],
        concessions: [
          const OrderConcessionItem(name: 'Combo 1: Dúo Clásico', quantity: 1, unitPrice: 34.5),
        ],
        totalAmount: 66.5,
        paymentMethod: 'Tarjeta Débito/Crédito',
        buyerName: 'Jhon Franklin',
        buyerDni: '72819402',
        buyerEmail: 'jhon.franklin@gmail.com',
        qrCodeData: 'CINEMARK-PE:ORD-CNK-829410:ROOM-XD1:SEATS-F5,F6',
        isUpcoming: true,
      );

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(home: TicketConfirmationView(order: order)),
      );
      await tester.pumpAndSettle();

      // Cabecera y éxito
      expect(find.text('TU BOLETO DIGITAL'), findsOneWidget);
      expect(find.text('¡Compra realizada con éxito!'), findsOneWidget);

      // Butacas destacadas y código de reserva legible
      expect(find.text('BUTACAS:'), findsOneWidget);
      expect(find.text('F5   F6'), findsOneWidget);
      expect(find.text('CÓDIGO DE RESERVA: CNK-829410'), findsOneWidget);

      // Retiro express de dulcería
      expect(find.text('Retiro Express en Confitería'), findsOneWidget);

      // Botón para volver al inicio
      expect(find.text('VOLVER AL INICIO'), findsOneWidget);
    });
  });

  group('11. Vista de Historial y Próximo Boleto (Views 9 y 10)', () {
    testWidgets('PurchaseHistoryView muestra pestañas y lista de boletos con botón de QR',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      PurchaseHistoryManager().clearHistory();

      final order = CompletedOrder(
        orderCode: 'CNK-123456',
        purchaseDate: DateTime.now(),
        movieTitle: 'Superman: Legacy',
        moviePosterUrl: '',
        movieClassification: 'TE',
        movieDuration: '130 min',
        cinemaName: 'Cinemark San Miguel',
        cinemaAddress: 'Av. La Marina',
        showtimeDate: DateTime.now(),
        showtimeHour: '20:00',
        roomName: 'Sala 4',
        format: '2D',
        language: 'Subtitulada',
        seats: ['D3'],
        tickets: [
          const OrderTicketItem(name: 'General', quantity: 1, unitPrice: 15.0),
        ],
        concessions: [],
        totalAmount: 15.0,
        paymentMethod: 'Yape',
        buyerName: 'María García',
        buyerDni: '71829304',
        buyerEmail: 'maria@test.com',
        qrCodeData: 'CINEMARK-PE:TEST',
        isUpcoming: true,
      );

      PurchaseHistoryManager().addOrder(order);

      await tester.pumpWidget(
        const MaterialApp(home: PurchaseHistoryView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('MIS BOLETOS Y COMPRAS'), findsOneWidget);
      expect(find.text('Próximas Funciones'), findsOneWidget);
      expect(find.text('Compras Pasadas'), findsOneWidget);
      expect(find.text('FUNCIÓN ACTIVA'), findsOneWidget);
      expect(find.text('VER BOLETO QR'), findsOneWidget);
    });

    testWidgets('UpcomingTicketCard muestra botón de acceso rápido para sala y butacas',
        (WidgetTester tester) async {
      final order = CompletedOrder(
        orderCode: 'CNK-999',
        purchaseDate: DateTime.now(),
        movieTitle: 'Avatar 3',
        moviePosterUrl: '',
        movieClassification: 'APT',
        movieDuration: '190 min',
        cinemaName: 'Cinemark Trujillo',
        cinemaAddress: 'Mallplaza',
        showtimeDate: DateTime.now(),
        showtimeHour: '18:30',
        roomName: 'Sala XD',
        format: '3D XD',
        language: 'Doblada',
        seats: ['G4', 'G5'],
        tickets: [],
        concessions: [],
        totalAmount: 40.0,
        paymentMethod: 'Tarjeta',
        buyerName: 'Test',
        buyerDni: '12345678',
        buyerEmail: 'test@mail.com',
        qrCodeData: 'TEST',
        isUpcoming: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpcomingTicketCard(order: order),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TU PRÓXIMA FUNCIÓN (ACCESO RÁPIDO)'), findsOneWidget);
      expect(find.text('18:30'), findsOneWidget);
      expect(find.text('Avatar 3'), findsOneWidget);
      expect(find.text('G4, G5'), findsOneWidget);
      expect(find.text('MOSTRAR QR PARA ENTRAR AL CINE'), findsOneWidget);
    });
  });
}
