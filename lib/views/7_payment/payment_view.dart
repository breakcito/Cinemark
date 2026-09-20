import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/telemetry/telemetry_tracker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/order_summary_bottom_sheet.dart';
import '../../data/mock_data.dart';
import '../../data/models/completed_order_model.dart';
import '../../data/models/purchase_session.dart';
import '../../data/purchase_history_manager.dart';
import '../8_ticket_confirmation/ticket_confirmation_view.dart';

enum PaymentMethodType { card, yape }

class PaymentView extends StatefulWidget {
  const PaymentView({super.key});

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  final _formKey = GlobalKey<FormState>();
  final _purchaseSession = PurchaseSession();

  // Método de pago seleccionado
  PaymentMethodType _selectedMethod = PaymentMethodType.card;

  // Controladores de datos del comprador
  late final TextEditingController _nameController;
  late final TextEditingController _dniController;
  late final TextEditingController _emailController;

  // Controladores de tarjeta
  late final TextEditingController _cardHolderController;
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();

  // Controladores de Yape
  final TextEditingController _yapePhoneController =
      TextEditingController(text: '987 654 321');
  final TextEditingController _yapeCodeController =
      TextEditingController(text: '123456');

  // Tipo de comprobante
  String _invoiceType = 'Boleta'; // 'Boleta' o 'Factura'
  bool _saveCard = false;
  bool _isProcessing = false;
  bool _isSummaryExpanded = true;

  @override
  void initState() {
    super.initState();
    TelemetryTracker().startStep('Payment');

    // Inicializar datos del comprador inteligente
    final activeParticipant = TelemetryTracker().participantCode;
    final trackerName = TelemetryTracker().participantName;
    final defaultName =
        (activeParticipant.isNotEmpty && activeParticipant != 'ANONIMO')
            ? (trackerName.isNotEmpty
                ? trackerName
                : 'Participante $activeParticipant')
            : 'Jhon Franklin';

    _nameController = TextEditingController(text: defaultName);
    _dniController = TextEditingController(text: '72819402');
    _emailController = TextEditingController(text: 'jhon.franklin@gmail.com');

    // Auto-rellenar titular de tarjeta sin obligar a escribirlo 2 veces (Heurística Usabilidad #5 y #6)
    _cardHolderController = TextEditingController(text: defaultName);

    // Si el comprador cambia su nombre, sincronizar con el titular
    _nameController.addListener(() {
      if (_cardHolderController.text.isEmpty ||
          _cardHolderController.text == defaultName) {
        _cardHolderController.text = _nameController.text;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    _cardHolderController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _yapePhoneController.dispose();
    _yapeCodeController.dispose();
    super.dispose();
  }

  double _calculateTicketsTotal() {
    final availableTypes = MockData.getTicketTypes();
    return _purchaseSession.calculateTotalAmount(availableTypes);
  }

  double _calculateConcessionsTotal() {
    final availableConcessions = MockData.getConcessionItems();
    return _purchaseSession.calculateConcessionsTotal(availableConcessions);
  }

  double _calculateGrandTotal() {
    return _calculateTicketsTotal() + _calculateConcessionsTotal();
  }

  Future<void> _processPayment() async {
    // Validar formulario
    if (!_formKey.currentState!.validate()) {
      TelemetryTracker().recordError(
        'Payment',
        'Formulario Inválido',
        'El usuario intentó pagar con campos incompletos o erróneos en $_selectedMethod',
      );
      return;
    }

    setState(() => _isProcessing = true);

    // Simular latencia de pasarela bancaria segura (1.2s)
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    // Generar código de orden único
    final randomCode =
        'CNK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // Generar datos para la orden
    final availableTypes = MockData.getTicketTypes();
    final ticketItems = <OrderTicketItem>[];
    _purchaseSession.ticketQuantities.forEach((typeId, qty) {
      final t = availableTypes.firstWhere((x) => x.id == typeId);
      ticketItems.add(
        OrderTicketItem(name: t.name, quantity: qty, unitPrice: t.price),
      );
    });
    for (final voucher in _purchaseSession.redeemedTickets) {
      ticketItems.add(
        OrderTicketItem(
          name: '${voucher.title} (Cupón)',
          quantity: 1,
          unitPrice: 0.0,
        ),
      );
    }

    final availableConcessions = MockData.getConcessionItems();
    final concessionItems = <OrderConcessionItem>[];
    _purchaseSession.concessionQuantities.forEach((itemId, qty) {
      final c = availableConcessions.firstWhere((x) => x.id == itemId);
      final price = c.getDiscountedPrice(_purchaseSession.isClubMember);
      concessionItems.add(
        OrderConcessionItem(name: c.name, quantity: qty, unitPrice: price),
      );
    });

    final movie = _purchaseSession.selectedMovie!;
    final showtime = _purchaseSession.selectedShowtime!;
    final cinema = _purchaseSession.selectedCinema!;

    final completedOrder = CompletedOrder(
      orderCode: randomCode,
      purchaseDate: DateTime.now(),
      movieTitle: movie.title,
      moviePosterUrl: movie.posterUrl,
      movieClassification: movie.rating,
      movieDuration: movie.duration,
      cinemaName: cinema.name,
      cinemaAddress: cinema.address,
      showtimeDate: showtime.date,
      showtimeHour: showtime.timeFormatted,
      roomName: showtime.roomName,
      format: showtime.format,
      language: showtime.language,
      seats: List.from(_purchaseSession.selectedSeats),
      tickets: ticketItems,
      concessions: concessionItems,
      totalAmount: _calculateGrandTotal(),
      paymentMethod: _selectedMethod == PaymentMethodType.card
          ? 'Tarjeta Débito/Crédito'
          : 'Yape',
      buyerName: _nameController.text.trim(),
      buyerDni: _dniController.text.trim(),
      buyerEmail: _emailController.text.trim(),
      qrCodeData:
          'CINEMARK-PE:ORD-$randomCode:ROOM-${showtime.roomName}:SEATS-${_purchaseSession.selectedSeats.join(",")}',
      isUpcoming: true,
    );

    // Guardar en gestor de compras
    PurchaseHistoryManager().addOrder(completedOrder);

    // Completar paso y finalizar sesión exitosamente en telemetría
    TelemetryTracker().completeStep('Payment');
    TelemetryTracker().finishSession(
      isCompleted: true,
      maxStepReached: 'Payment',
    );

    // Detener temporizador
    _purchaseSession.stopTimer();

    setState(() => _isProcessing = false);

    // Navegar a la Vista 8: Confirmación / Boleto QR
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TicketConfirmationView(order: completedOrder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _calculateGrandTotal();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'PAGO Y CONFIRMACIÓN',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Temporizador de sesión
          AnimatedBuilder(
            animation: _purchaseSession,
            builder: (context, _) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _purchaseSession.isTimerCritical
                      ? AppColors.error.withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _purchaseSession.isTimerCritical
                        ? AppColors.error
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: _purchaseSession.isTimerCritical
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _purchaseSession.formattedTimeRemaining,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _purchaseSession.isTimerCritical
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Resumen Colapsable de Compra (Heurística #1: Visibilidad)
                  _buildOrderSummaryCard(grandTotal),
                  const SizedBox(height: 16),

                  // 2. Datos del Comprador (con auto-rellenado y validación)
                  _buildBuyerInfoSection(),
                  const SizedBox(height: 16),

                  // 3. Método de Pago (Pestañas Card / Yape)
                  _buildPaymentMethodSelector(),
                  const SizedBox(height: 14),

                  // 4. Formulario específico del método de pago
                  if (_selectedMethod == PaymentMethodType.card)
                    _buildCardPaymentForm()
                  else
                    _buildYapePaymentForm(),

                  const SizedBox(height: 16),

                  // 5. Tipo de Comprobante
                  _buildInvoiceSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Barra inferior con botón de pago
            _buildBottomPaymentBar(grandTotal),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(double grandTotal) {
    final movie = _purchaseSession.selectedMovie;
    final showtime = _purchaseSession.selectedShowtime;
    final cinema = _purchaseSession.selectedCinema;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() => _isSummaryExpanded = !_isSummaryExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie?.title ?? 'Película',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${cinema?.name ?? ''} • ${showtime?.timeFormatted ?? ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'S/ ${grandTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isSummaryExpanded ? 'Ocultar' : 'Ver detalle',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Icon(
                            _isSummaryExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            firstCurve: Curves.easeInOut,
            secondCurve: Curves.easeInOut,
            crossFadeState: _isSummaryExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Asientos
                      const Text(
                        'Butacas seleccionadas:',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _purchaseSession.selectedSeats.map((seat) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              seat,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Desglose de entradas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Entradas (${_purchaseSession.totalTicketCount}):',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'S/ ${_calculateTicketsTotal().toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Desglose de confitería
                      if (_purchaseSession.totalConcessionItemsCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Confitería (${_purchaseSession.totalConcessionItemsCount} items):',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'S/ ${_calculateConcessionsTotal().toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => OrderSummaryBottomSheet.show(context),
                          icon: const Icon(Icons.receipt_long, size: 16),
                          label: const Text(
                            'VER DESGLOSE COMPLETO DE COMPRA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerInfoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Datos del Comprador',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre y Apellido',
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _dniController,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: 'DNI / CE',
                    counterText: '',
                    prefixIcon: Icon(Icons.fingerprint, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().length < 8)
                      ? 'DNI inválido'
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedMethod = PaymentMethodType.card);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedMethod == PaymentMethodType.card
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _selectedMethod == PaymentMethodType.card
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card,
                      size: 18,
                      color: _selectedMethod == PaymentMethodType.card
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Tarjeta Débito / Crédito',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _selectedMethod == PaymentMethodType.card
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedMethod == PaymentMethodType.card
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedMethod = PaymentMethodType.yape);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedMethod == PaymentMethodType.yape
                      ? const Color(0xFF742284) // Morado Yape
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _selectedMethod == PaymentMethodType.yape
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_android,
                      size: 18,
                      color: _selectedMethod == PaymentMethodType.yape
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Pagar con Yape',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _selectedMethod == PaymentMethodType.yape
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedMethod == PaymentMethodType.yape
                              ? Colors.white
                              : AppColors.textSecondary,
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
    );
  }

  Widget _buildCardPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Datos de la Tarjeta',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.payment, size: 16, color: Colors.blue.shade800),
                  const SizedBox(width: 4),
                  const Text(
                    'Visa / MC / Amex',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Número de tarjeta con espaciado cada 4 dígitos
          TextFormField(
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              _CardNumberInputFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Número de Tarjeta',
              hintText: '4557 1234 5678 9010',
              prefixIcon: Icon(Icons.credit_card, size: 20),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) {
              if (v == null || v.replaceAll(' ', '').length < 16) {
                return 'Ingresa los 16 dígitos de la tarjeta';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),

          // Titular de la tarjeta (Auto-rellenado para resolver queja del usuario)
          TextFormField(
            controller: _cardHolderController,
            decoration: const InputDecoration(
              labelText: 'Nombre del Titular (Como figura en la tarjeta)',
              prefixIcon: Icon(Icons.person_pin, size: 20),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ingresa el nombre del titular'
                : null,
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              // Vencimiento MM/AA
              Expanded(
                child: TextFormField(
                  controller: _cardExpiryController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    _CardExpiryInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Vence (MM/AA)',
                    hintText: '12/28',
                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 5) return 'Inválido';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),

              // CVV con tooltip explicativo (Prevención de errores)
              Expanded(
                child: TextFormField(
                  controller: _cardCvvController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    hintText: '123',
                    counterText: '',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: Tooltip(
                      message: 'Código de 3 o 4 dígitos al reverso de tu tarjeta',
                      child: Icon(
                        Icons.help_outline,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 3) return '3 dígitos';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _saveCard,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _saveCard = val ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Guardar tarjeta para futuras compras',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYapePaymentForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF742284).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF742284).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  color: Color(0xFF742284),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paga al instante con tu Yape',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF742284),
                      ),
                    ),
                    Text(
                      'Sin comisiones, confirmación en tiempo real',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _yapePhoneController,
            keyboardType: TextInputType.phone,
            maxLength: 12,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\s]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Número de Celular Yape',
              hintText: '987 654 321',
              counterText: '',
              prefixIcon: Icon(Icons.phone_iphone, size: 20),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) {
              final clean = (v ?? '').replaceAll(RegExp(r'\s+'), '');
              if (clean.length != 9 || !clean.startsWith('9')) {
                return 'Ingresa un celular válido de 9 dígitos';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: _yapeCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Código de Aprobación Yape (6 dígitos)',
              hintText: 'Ej. 123456',
              counterText: '',
              prefixIcon: Icon(Icons.pin, size: 20),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) {
              final clean = (v ?? '').trim();
              if (clean.length != 6) {
                return 'Ingresa el código de 6 dígitos de tu Yape';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF742284)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Abre tu app Yape > Menú > Código de aprobación y digítalo aquí para validar el pago.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF742284)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comprobante de Pago',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Boleta Electrónica', style: TextStyle(fontSize: 11)),
                selected: _invoiceType == 'Boleta',
                selectedColor: AppColors.primaryLight,
                onSelected: (val) {
                  if (val) setState(() => _invoiceType = 'Boleta');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Factura (RUC)', style: TextStyle(fontSize: 11)),
                selected: _invoiceType == 'Factura',
                selectedColor: AppColors.primaryLight,
                onSelected: (val) {
                  if (val) setState(() => _invoiceType = 'Factura');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPaymentBar(double grandTotal) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'TOTAL A PAGAR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => OrderSummaryBottomSheet.show(context),
                    child: const Text(
                      'Ver detalle',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'S/ ${grandTotal.toStringAsFixed(2)}',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedMethod == PaymentMethodType.yape
                    ? const Color(0xFF742284)
                    : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'PAGAR S/ ${grandTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Formateador de tarjeta en bloques de 4 dígitos
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(' ', '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

// Formateador de fecha de vencimiento MM/AA
class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll('/', '');
    if (text.length > 4) text = text.substring(0, 4);

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
