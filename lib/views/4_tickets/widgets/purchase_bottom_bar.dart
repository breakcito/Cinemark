import 'package:flutter/material.dart';
import '../../../core/telemetry/telemetry_tracker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/order_summary_bottom_sheet.dart';

class PurchaseBottomBar extends StatelessWidget {
  final int totalTickets;
  final double totalAmount;
  final VoidCallback onContinue;

  const PurchaseBottomBar({
    super.key,
    required this.totalTickets,
    required this.totalAmount,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final canContinue = totalTickets > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              // Área clickeable del Carrito para ver desglose de entradas elegidas (Heurística #6 y #7)
              Expanded(
                child: InkWell(
                  onTap: () => OrderSummaryBottomSheet.show(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Icono Carrito con Badge de cantidad
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                            if (totalTickets > 0)
                              Positioned(
                                top: -6,
                                right: -8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$totalTickets',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Total acumulado y botón "Ver detalle"
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'S/ ${totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.info_outline,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      totalTickets == 0
                                          ? '0 entradas seleccionadas'
                                          : '$totalTickets ${totalTickets == 1 ? 'entrada' : 'entradas'}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '• Ver detalle',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón CONTINUAR
              ElevatedButton(
                onPressed: canContinue
                    ? onContinue
                    : () {
                        TelemetryTracker().recordError(
                          'Tickets',
                          'Continuar Sin Entradas',
                          'El usuario intentó continuar sin haber seleccionado ninguna entrada o cupón',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Por favor selecciona al menos una entrada o canjea un cupón.',
                            ),
                            backgroundColor: AppColors.error,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: canContinue
                      ? AppColors.primary
                      : const Color(0xFF555555),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(125, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(21),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CONTINUAR',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: canContinue ? Colors.white : Colors.white60,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: canContinue ? Colors.white : Colors.white60,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
