import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/telemetry/telemetry_tracker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cinema_model.dart';
import '../../../data/purchase_history_manager.dart';
import '../../8_ticket_confirmation/ticket_confirmation_view.dart';

class HomeHeader extends StatelessWidget {
  final Cinema selectedCinema;
  final VoidCallback onSelectCinemaTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onHistoryTap;

  const HomeHeader({
    super.key,
    required this.selectedCinema,
    required this.onSelectCinemaTap,
    this.onSearchTap,
    this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TelemetryTracker(),
      builder: (context, _) {
        final tracker = TelemetryTracker();
        final isEvaluatingParticipant = tracker.hasActiveParticipant;
        final displayName = isEvaluatingParticipant
            ? tracker.participantName
            : AppConstants.defaultUserName;
        final initials = isEvaluatingParticipant
            ? (tracker.participantName.isNotEmpty &&
                    !tracker.participantName.startsWith('Participante')
                ? _extractInitials(tracker.participantName)
                : tracker.participantCode)
            : AppConstants.defaultUserInitials;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              // Perfil de Usuario o Sujeto Evaluado
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isEvaluatingParticipant
                          ? AppColors.primary
                          : AppColors.primaryDark,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HOLA, ${displayName.toUpperCase()}!',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEvaluatingParticipant
                              ? 'Evaluación Activa: ${tracker.participantCode}'
                              : 'Socio Cinemark Club',
                          style: TextStyle(
                            fontSize: 11,
                            color: isEvaluatingParticipant
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Icono de búsqueda
                  IconButton(
                    icon: const Icon(Icons.search, color: AppColors.textPrimary),
                    tooltip: 'Buscar en Cinemark',
                    onPressed: onSearchTap,
                  ),
                ],
              ),

              // Botón vibrante de Próxima Función (Acceso Rápido Inteligente en la parte superior)
              ListenableBuilder(
                listenable: PurchaseHistoryManager(),
                builder: (context, _) {
                  final nextOrder = PurchaseHistoryManager().nextUpcomingOrder;
                  if (nextOrder == null) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE50914), Color(0xFFB81D24)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE50914).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TicketConfirmationView(order: nextOrder),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.confirmation_number_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'PRÓXIMA FUNCIÓN',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.primary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Hoy • ${nextOrder.showtimeHour}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${nextOrder.movieTitle} (${nextOrder.roomName} • Butacas: ${nextOrder.seats.join(", ")})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'VER QR',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
          // Barra de Cartelera por Cine
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: Row(
              children: [
                const Text(
                  'CARTELERA POR CINE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  height: 16,
                  width: 1,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onSelectCinemaTap,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            selectedCinema.name.replaceAll('Cinemark ', ''),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  String _extractInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return 'P';
  }
}
