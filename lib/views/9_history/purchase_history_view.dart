import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/telemetry/telemetry_tracker.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/completed_order_model.dart';
import '../../data/purchase_history_manager.dart';
import '../8_ticket_confirmation/ticket_confirmation_view.dart';

class PurchaseHistoryView extends StatefulWidget {
  const PurchaseHistoryView({super.key});

  @override
  State<PurchaseHistoryView> createState() => _PurchaseHistoryViewState();
}

class _PurchaseHistoryViewState extends State<PurchaseHistoryView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _historyManager = PurchaseHistoryManager();

  @override
  void initState() {
    super.initState();
    TelemetryTracker().startStep('PurchaseHistory');
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'MIS BOLETOS Y COMPRAS',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Próximas Funciones'),
            Tab(text: 'Compras Pasadas'),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _historyManager,
        builder: (context, _) {
          final upcoming = _historyManager.upcomingOrders;
          final past = _historyManager.pastOrders;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOrdersList(upcoming, isUpcomingTab: true),
              _buildOrdersList(past, isUpcomingTab: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(List<CompletedOrder> orders, {required bool isUpcomingTab}) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUpcomingTab
                      ? Icons.confirmation_number_outlined
                      : Icons.history,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isUpcomingTab
                    ? 'No tienes boletos próximos activos'
                    : 'Aún no tienes historial de compras anteriores',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isUpcomingTab
                    ? 'Cuando compres entradas para una película, tus boletos con código QR para entrar al cine aparecerán aquí.'
                    : 'Tus funciones vistas y boletos anteriores se archivarán en esta pestaña.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (isUpcomingTab) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('EXPLORAR CARTELERA'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Setiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    final dayName = weekdays[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName ${date.day} de $monthName';
  }

  Widget _buildOrderCard(CompletedOrder order) {
    final formattedDate = _formatDate(order.showtimeDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: order.isUpcoming
              ? AppColors.primary.withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // Encabezado de la tarjeta con estado y fecha
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: order.isUpcoming
                  ? AppColors.primaryLight
                  : Colors.grey.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      order.isUpcoming
                          ? Icons.access_time_filled
                          : Icons.check_circle_outline,
                      size: 14,
                      color: order.isUpcoming
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order.isUpcoming ? 'FUNCIÓN ACTIVA' : 'FUNCIÓN FINALIZADA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: order.isUpcoming
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  order.orderCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    order.moviePosterUrl,
                    width: 60,
                    height: 85,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 85,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.movie, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info de función
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.movieTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.cinemaName} • ${order.roomName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$formattedDate - ${order.showtimeHour}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Asientos
                      Wrap(
                        spacing: 4,
                        children: order.seats.map((seat) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              seat,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Botón de acción: Ver Boleto QR (en 1 tap)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: S/ ${order.totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TicketConfirmationView(order: order),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code, size: 16),
                  label: const Text(
                    'VER BOLETO QR',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
