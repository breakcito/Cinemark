import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cinema_model.dart';

class HomeHeader extends StatelessWidget {
  final Cinema selectedCinema;
  final VoidCallback onSelectCinemaTap;
  final VoidCallback? onSurveyTap;

  const HomeHeader({
    super.key,
    required this.selectedCinema,
    required this.onSelectCinemaTap,
    this.onSurveyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          // Perfil de Usuario
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  AppConstants.defaultUserInitials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOLA, ${AppConstants.defaultUserName.toUpperCase()}!',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Row(
                      children: [
                        Text(
                          'Acceder a mi perfil',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Botón de Encuesta SUS (Tesis)
              if (onSurveyTap != null)
                IconButton(
                  icon: const Icon(Icons.rate_review_outlined, color: AppColors.primary),
                  tooltip: 'Encuesta SUS (Tesis)',
                  onPressed: onSurveyTap,
                ),
              // Icono de búsqueda rápida
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.textPrimary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Buscador de películas activado'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
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
  }
}
