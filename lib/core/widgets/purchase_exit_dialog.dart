import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../telemetry/telemetry_tracker.dart';

class PurchaseExitDialog {
  /// Muestra un modal de advertencia al usuario indicando que si sale del proceso
  /// de compra, todo su progreso (entradas, butacas, confitería) se eliminará.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿Salir del proceso de compra?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Si sales ahora, se liberará el horario reservado y se eliminará todo tu progreso (entradas, asientos y productos seleccionados).',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CONTINUAR COMPRA',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              TelemetryTracker().recordError(
                'PurchaseFlow',
                'UserCancelled',
                'El usuario confirmó salir del proceso de compra tras la advertencia',
              );
              Navigator.pop(ctx, true);
            },
            child: const Text(
              'SALIR Y ELIMINAR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
