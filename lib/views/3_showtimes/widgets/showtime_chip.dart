import 'package:flutter/material.dart';
import '../../../core/telemetry/telemetry_tracker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/showtime_model.dart';

class ShowtimeChip extends StatelessWidget {
  final Showtime showtime;
  final bool isSelected;
  final ValueChanged<Showtime> onSelected;

  const ShowtimeChip({
    super.key,
    required this.showtime,
    this.isSelected = false,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSoldOut = showtime.isSoldOut;

    return InkWell(
      onTap: () {
        if (isSoldOut) {
          TelemetryTracker().recordError(
            'Horarios',
            'Selección de Función Agotada',
            'El usuario intentó seleccionar el horario ${showtime.timeFormatted} (${showtime.roomName}) que se encuentra agotado',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Función agotada. Por favor selecciona otro horario con butacas disponibles.',
              ),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        onSelected(showtime);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 105,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSoldOut
              ? Colors.grey.shade100
              : isSelected
                  ? AppColors.primaryLight
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSoldOut
                ? Colors.grey.shade300
                : isSelected
                    ? AppColors.primary
                    : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSoldOut
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              showtime.timeFormatted,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isSoldOut
                    ? Colors.grey.shade400
                    : isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                decoration: isSoldOut ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              showtime.roomName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSoldOut ? Colors.grey.shade400 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isSoldOut
                    ? Colors.grey.shade300
                    : showtime.isAlmostFull
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isSoldOut
                    ? 'Agotado'
                    : showtime.isAlmostFull
                        ? '¡${showtime.availableSeats} disp.!'
                        : '${showtime.availableSeats} disp.',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isSoldOut
                      ? Colors.grey.shade600
                      : showtime.isAlmostFull
                          ? AppColors.warning
                          : AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
