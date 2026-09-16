import 'package:flutter/material.dart';
import '../../../core/telemetry/telemetry_tracker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_data.dart';
import '../../../data/models/purchase_session.dart';

class BatchCouponSection extends StatefulWidget {
  const BatchCouponSection({super.key});

  @override
  State<BatchCouponSection> createState() => _BatchCouponSectionState();
}

class _BatchCouponSectionState extends State<BatchCouponSection> {
  final TextEditingController _codeController = TextEditingController();
  final PurchaseSession _session = PurchaseSession();
  String? _errorMessage;
  String? _successMessage;

  void _redeemCode(String code) {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (code.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa un código de cupón';
      });
      return;
    }

    final batchCoupon = MockData.resolveBatchCoupon(code);
    if (batchCoupon == null) {
      TelemetryTracker().recordError(
        'Tickets',
        'Cupón Inválido',
        'Código no reconocido: "$code"',
      );
      setState(() {
        _errorMessage = 'Código no válido o vencido. Intenta con PACK3X o CORP2X.';
      });
      return;
    }

    // Agregar lote de tickets
    _session.addBatchRedeemedTickets(batchCoupon.generatedTickets);
    _codeController.clear();

    setState(() {
      _successMessage =
          '¡Éxito! Se canjearon ${batchCoupon.totalTickets} entradas con el código ${batchCoupon.code}.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_successMessage!),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final redeemedTickets = _session.redeemedTickets;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa el número del código',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Puedes ingresar códigos individuales o códigos grupales (pack multi-ticket) que canjean varias entradas a la vez.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              // Campo de texto y Botón AGREGAR
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Ej. PACK3X, CORP2X...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        errorText: _errorMessage,
                      ),
                      onSubmitted: _redeemCode,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _redeemCode(_codeController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF616161),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      'AGREGAR',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Chips de prueba rápida para la demostración del prototipo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt, size: 16, color: Colors.amber),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Códigos de prueba rápida para evaluación:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.confirmation_number, size: 14),
                          label: const Text('Pack 3x (PACK3X)', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.white,
                          onPressed: () {
                            _codeController.text = 'PACK3X';
                            _redeemCode('PACK3X');
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.people, size: 14),
                          label: const Text('Dúo 2x (CORP2X)', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.white,
                          onPressed: () {
                            _codeController.text = 'CORP2X';
                            _redeemCode('CORP2X');
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.person, size: 14),
                          label: const Text('1x Individual', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.white,
                          onPressed: () {
                            _codeController.text = 'TICKET1X';
                            _redeemCode('TICKET1X');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Lista de Tickets Canjeados en Lote
              if (redeemedTickets.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ENTRADAS CANJEADAS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${redeemedTickets.length} entradas activas',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: redeemedTickets.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final ticket = redeemedTickets[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.success,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ticket.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Código lote: ${ticket.parentBatchCode} • ${ticket.description}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'S/ 0.00',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Control del usuario (Heurística #3): Puede remover un ticket individual del lote
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                            onPressed: () {
                              _session.removeRedeemedTicket(ticket.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Entrada de cupón eliminada'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            tooltip: 'Quitar esta entrada',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
