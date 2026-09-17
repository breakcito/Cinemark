import 'package:flutter/material.dart';
import '../../core/telemetry/telemetry_tracker.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../data/models/movie_model.dart';
import '../../data/models/purchase_session.dart';
import '../../data/models/showtime_model.dart';
import '../../data/models/ticket_model.dart';
import 'widgets/batch_coupon_section.dart';
import 'widgets/purchase_bottom_bar.dart';
import 'widgets/ticket_counter_tile.dart';
import '../5_seats/seats_view.dart';
import '../../core/widgets/purchase_exit_dialog.dart';

class TicketsView extends StatefulWidget {
  final Movie movie;
  final Showtime showtime;

  const TicketsView({
    super.key,
    required this.movie,
    required this.showtime,
  });

  @override
  State<TicketsView> createState() => _TicketsViewState();
}

class _TicketsViewState extends State<TicketsView>
    with SingleTickerProviderStateMixin {
  final PurchaseSession _session = PurchaseSession();
  late TabController _tabController;
  late List<TicketType> _availableTicketTypes;

  @override
  void initState() {
    super.initState();
    TelemetryTracker().startStep('Tickets');

    _tabController = TabController(length: 2, vsync: this);
    _availableTicketTypes = MockData.getTicketTypes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onContinue() {
    TelemetryTracker().completeStep('Tickets');

    final totalTickets = _session.totalTicketCount;
    final totalAmount = _session.calculateTotalAmount(_availableTicketTypes);

    // Obtener desglose de tarifas seleccionadas y cupones canjeados
    final selectedItems = <Map<String, dynamic>>[];
    for (final ticket in _availableTicketTypes) {
      final qty = _session.ticketQuantities[ticket.id] ?? 0;
      if (qty > 0) {
        selectedItems.add({
          'name': ticket.name,
          'qty': qty,
          'price': ticket.price,
          'subtotal': ticket.price * qty,
        });
      }
    }
    final voucherCount = _session.redeemedTickets.length;

    // Diálogo de confirmación del paso 4 hacia el paso 5 (Asientos)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Entradas Confirmadas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Has seleccionado $totalTickets ${totalTickets == 1 ? 'entrada' : 'entradas'} para "${widget.movie.title}".',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            // Desglose de selección (Heurística Usabilidad #1 y #6)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in selectedItems)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item['qty']}x ${item['name']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            'S/ ${(item['subtotal'] as double).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (voucherCount > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$voucherCount x Cupón Canjeado (${_session.redeemedTickets.map((t) => t.parentBatchCode).toSet().join(", ")})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                          const Text(
                            'S/ 0.00',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a pagar:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'S/ ${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_seat, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Siguiente etapa: Selección interactiva de los $totalTickets asientos en sala.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SeatsView(
                        movie: widget.movie,
                        showtime: widget.showtime,
                      ),
                    ),
                  );
                },
                child: const Text('CONTINUAR A ASIENTOS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final cinema = _session.selectedCinema ?? MockData.cinemas.first;
        final totalAmount = _session.calculateTotalAmount(_availableTicketTypes);
        final totalTickets = _session.totalTicketCount;

        Future<void> handleExit() async {
          final shouldExit = await PurchaseExitDialog.show(context);
          if (shouldExit && context.mounted) {
            _session.resetSession();
            Navigator.pop(context);
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await handleExit();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                tooltip: 'Regresar a horarios',
                onPressed: handleExit,
              ),
              titleSpacing: 0,
              title: Text(
                '${widget.movie.title} - ${cinema.name}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                // Temporizador activo visible desde que eligió horario (Heurística #1)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _session.formattedTimeRemaining,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _session.isTimerCritical
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                        tooltip: 'Cancelar compra y salir',
                        onPressed: handleExit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
              // Hero Session Banner
              Stack(
                children: [
                  Image.network(
                    widget.movie.backdropUrl,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 110,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Hoy, ${widget.showtime.timeFormatted} hrs • ${widget.showtime.roomName} • ${widget.showtime.format} ${widget.showtime.language}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // TabBar: TARIFAS & CANJEA TU CÓDIGO
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'TARIFAS'),
                    Tab(text: 'CANJEA TU CÓDIGO'),
                  ],
                ),
              ),

              // Contenido de Tabs
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Tarifas
                    _buildTarifasTab(),
                    // Tab 2: Canje de Cupones
                    const BatchCouponSection(),
                  ],
                ),
              ),

              // Barra inferior del Carrito y Botón Continuar
              PurchaseBottomBar(
                totalTickets: totalTickets,
                totalAmount: totalAmount,
                onContinue: _onContinue,
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  Widget _buildTarifasTab() {
    // Agrupar tarifas por categoría para reducir la sobrecarga cognitiva (Heurística #8)
    final categories = <String, List<TicketType>>{};
    for (final t in _availableTicketTypes) {
      categories.putIfAbsent(t.category, () => []).add(t);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        // Aviso legal amigable
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surfaceVariant,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Niños mayores a 2 años pagan sus entradas',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              SizedBox(height: 2),
              Text(
                'Los precios de las entradas incluyen el cargo por servicio online.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        // Secciones categorizadas de tarifas
        for (final entry in categories.entries) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            color: const Color(0xFFE8E8EC),
            child: Text(
              entry.key.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: Color(0xFF555555),
              ),
            ),
          ),
          for (final ticketType in entry.value)
            TicketCounterTile(
              ticketType: ticketType,
              quantity: _session.ticketQuantities[ticketType.id] ?? 0,
              onQuantityChanged: (delta) {
                _session.updateTicketQuantity(ticketType.id, delta);
              },
            ),
        ],
      ],
    );
  }
}
