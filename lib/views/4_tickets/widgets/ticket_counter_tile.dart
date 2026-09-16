import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ticket_model.dart';

class TicketCounterTile extends StatelessWidget {
  final TicketType ticketType;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  const TicketCounterTile({
    super.key,
    required this.ticketType,
    required this.quantity,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ticketType.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (ticketType.isRecommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'MEJOR TARIFA',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      ticketType.formattedPrice,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (ticketType.pointsBonus > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '+ ${ticketType.pointsBonus} puntos',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (ticketType.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    ticketType.description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Stepper de Cantidad (Touch target >= 44x44 dp)
          Row(
            children: [
              if (quantity > 0) ...[
                IconButton(
                  onPressed: () => onQuantityChanged(-1),
                  icon: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.remove,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  alignment: Alignment.center,
                  child: Text(
                    '$quantity',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
              IconButton(
                onPressed: () => onQuantityChanged(1),
                icon: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
