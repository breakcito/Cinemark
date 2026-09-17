import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/mock_data.dart';
import '../../data/models/purchase_session.dart';
import '../theme/app_colors.dart';

class OrderSummaryBottomSheet extends StatelessWidget {
  final VoidCallback? onContinueAction;
  final String? continueButtonText;

  const OrderSummaryBottomSheet({
    super.key,
    this.onContinueAction,
    this.continueButtonText,
  });

  static void show(
    BuildContext context, {
    VoidCallback? onContinueAction,
    String? continueButtonText,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderSummaryBottomSheet(
        onContinueAction: onContinueAction,
        continueButtonText: continueButtonText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = PurchaseSession();
    final ticketTypes = MockData.getTicketTypes();
    final concessionItems = MockData.getConcessionItems();

    final ticketsTotal = session.calculateTotalAmount(ticketTypes);
    final concessionsTotal = session.calculateConcessionsTotal(concessionItems);
    final grandTotal = ticketsTotal + concessionsTotal;

    // Obtener desglose de tarifas seleccionadas
    final selectedTariffItems = <Map<String, dynamic>>[];
    session.ticketQuantities.forEach((typeId, qty) {
      if (qty > 0) {
        final t = ticketTypes.firstWhere(
          (item) => item.id == typeId,
          orElse: () => MockData.getTicketTypes().first,
        );
        selectedTariffItems.add({
          'name': t.name,
          'qty': qty,
          'unitPrice': t.price,
          'subtotal': t.price * qty,
        });
      }
    });

    // Obtener desglose de confitería seleccionada
    final selectedSnackItems = <Map<String, dynamic>>[];
    session.concessionQuantities.forEach((itemId, qty) {
      if (qty > 0) {
        final item = concessionItems.firstWhere(
          (i) => i.id == itemId,
          orElse: () => MockData.getConcessionItems().first,
        );
        final unitPrice = item.getDiscountedPrice(session.isClubMember);
        selectedSnackItems.add({
          'name': item.name,
          'emoji': item.iconEmoji,
          'qty': qty,
          'unitPrice': unitPrice,
          'subtotal': unitPrice * qty,
        });
      }
    });

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle de arrastre superior
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[350],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Encabezado del Resumen
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Resumen de Compra',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    tooltip: 'Cerrar resumen',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.8),

            // Contenido escroleable
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                children: [
                  // Datos de Película y Función
                  if (session.selectedMovie != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              session.selectedMovie!.posterUrl,
                              width: 42,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 42,
                                height: 56,
                                color: Colors.grey[300],
                                child: const Icon(Icons.movie, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.selectedMovie!.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${session.selectedCinema?.name ?? "Mallplaza Trujillo"} • ${session.selectedShowtime?.format ?? "2D"}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (session.selectedShowtime != null)
                                  Text(
                                    'Función: ${session.selectedShowtime!.timeFormatted} • ${session.selectedShowtime!.roomName}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sección 1: Entradas y Tarifas Elegidas
                  _buildSectionHeader(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Entradas Seleccionadas (${session.totalTicketCount})',
                  ),
                  const SizedBox(height: 8),

                  if (selectedTariffItems.isEmpty && session.redeemedTickets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Aún no has seleccionado entradas',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                    ),

                  ...selectedTariffItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item['qty']}x ${item['name']}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            'S/ ${(item['subtotal'] as double).toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Tickets canjeados por cupones
                  if (session.redeemedTickets.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...session.redeemedTickets.map((t) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${t.title} (${t.parentBatchCode})',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              'Canje S/ 0.00',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Butacas seleccionadas
                  if (session.selectedSeats.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chair_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Butacas asignadas: ',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              session.selectedSeats.join(', '),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Sección 2: Confitería Elegida
                  _buildSectionHeader(
                    icon: Icons.fastfood_outlined,
                    title: 'Confitería (${session.totalConcessionItemsCount} items)',
                  ),
                  const SizedBox(height: 8),

                  if (selectedSnackItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'No has agregado productos de confitería.',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                    ),

                  ...selectedSnackItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['emoji'] as String, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item['qty']}x ${item['name']}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            'S/ ${(item['subtotal'] as double).toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  if (session.isClubMember && selectedSnackItems.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.stars, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          'Precios con descuento Club Cinemark aplicados',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Pie totalizador fijo
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal Entradas:',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        'S/ ${ticketsTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal Confitería:',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        'S/ ${concessionsTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL A PAGAR:',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'S/ ${grandTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (onContinueAction != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onContinueAction!();
                        },
                        child: Text(
                          continueButtonText ?? 'CONTINUAR AL PAGO',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
