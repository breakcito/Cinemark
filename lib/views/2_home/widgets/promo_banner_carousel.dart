import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PromoItem {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final String actionLabel;
  final Color bgColor;
  final Color accentColor;
  final IconData icon;

  const PromoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.actionLabel,
    required this.bgColor,
    required this.accentColor,
    required this.icon,
  });
}

class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key});

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  final List<PromoItem> _promos = const [
    PromoItem(
      id: 'p1',
      title: '+TOPPINGS CINEMARK',
      subtitle: 'Galletas, wafers o grageas para tu pop corn a solo S/ 3.00 c/u',
      tag: 'NUEVO',
      actionLabel: 'VER COMBOS',
      bgColor: Color(0xFF8B0000), // Dark Red
      accentColor: Colors.amber,
      icon: Icons.fastfood,
    ),
    PromoItem(
      id: 'p2',
      title: 'MARTES DE D-BOX',
      subtitle: 'Asientos con movimiento sincronizado con la película a solo S/ 20.00',
      tag: 'PROMOCIÓN',
      actionLabel: 'CONOCE MÁS',
      bgColor: Color(0xFF1A1A1A), // Dark Black
      accentColor: Color(0xFFE53935),
      icon: Icons.chair,
    ),
    PromoItem(
      id: 'p3',
      title: 'MIÉRCOLES MITAD DE PRECIO',
      subtitle: 'Todas las entradas al 50% en salas 2D y XD tradicionales',
      tag: 'BENEFICIO',
      actionLabel: 'VER CARTELERA',
      bgColor: Color(0xFFB71C1C),
      accentColor: Colors.white,
      icon: Icons.local_offer,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _promos.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onPromoTap(PromoItem promo) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    promo.tag,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              promo.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              promo.subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Beneficio "${promo.title}" aplicado'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              child: Text(promo.actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _promos.length,
            itemBuilder: (context, index) {
              final promo = _promos[index];
              return GestureDetector(
                onTap: () => _onPromoTap(promo),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: promo.bgColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: promo.bgColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: promo.accentColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                promo.tag,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              promo.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              promo.subtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          promo.icon,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _promos.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == index ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? AppColors.primary
                    : AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
