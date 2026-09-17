import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/telemetry/telemetry_tracker.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../data/models/cinema_model.dart';
import '../../data/models/movie_model.dart';
import '../../data/models/purchase_session.dart';
import '../3_showtimes/showtimes_view.dart';
import '../9_history/purchase_history_view.dart';
import '../researcher/thesis_panel_view.dart';
import 'widgets/cinema_selector_sheet.dart';
import 'widgets/featured_movie_slider.dart';
import 'widgets/home_header.dart';
import 'widgets/movie_card.dart';
import 'widgets/notification_permission_banner.dart';
import 'widgets/promo_banner_carousel.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentBottomNavIndex = 0;
  bool _showNotificationBanner = true;
  bool _filterOnlyAvailable = true; // Heurística #5: Prevención de errores

  late Cinema _currentCinema;
  late List<Movie> _allMovies;

  @override
  void initState() {
    super.initState();
    TelemetryTracker().startStep('Home');

    final sessionCinema = PurchaseSession().selectedCinema;
    _currentCinema = sessionCinema ??
        MockData.cinemas.firstWhere(
          (c) => c.id == AppConstants.defaultCinemaId,
          orElse: () => MockData.cinemas.first,
        );
    _allMovies = MockData.getMovies();
  }

  void _openCinemaSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CinemaSelectorSheet(
        currentCinema: _currentCinema,
        onCinemaSelected: (newCinema) {
          setState(() {
            _currentCinema = newCinema;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cartelera actualizada para ${newCinema.name}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _onMovieSelected(Movie movie) {
    // Si la película no tiene funciones en este cine, advertir proactivamente
    final hasShowtimes = movie.hasShowtimesInCinema(_currentCinema.id);
    if (!hasShowtimes) {
      TelemetryTracker().recordError(
        'Home',
        'Película No Disponible',
        'El usuario seleccionó "${movie.title}" que no tiene funciones en ${_currentCinema.name}',
      );
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Función No Disponible', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            'La película "${movie.title}" no cuenta con funciones programadas en ${_currentCinema.name}. ¿Deseas ver otras salas disponibles en Perú?',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openCinemaSelector();
              },
              child: const Text('Cambiar Cine'),
            ),
          ],
        ),
      );
      return;
    }

    TelemetryTracker().completeStep('Home');
    PurchaseSession().selectMovie(movie);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShowtimesView(movie: movie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtrado inteligente según la heurística de usabilidad
    final presaleMovies = _allMovies.where((m) => m.isPresale).toList();
    final featuredMovies = _allMovies.where((m) => m.isFeatured).toList();

    final billboardMovies = _allMovies.where((m) {
      if (!_filterOnlyAvailable) return true;
      return m.hasShowtimesInCinema(_currentCinema.id);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Cabecera superior con saludo y cine
            SliverToBoxAdapter(
              child: HomeHeader(
                selectedCinema: _currentCinema,
                onSelectCinemaTap: _openCinemaSelector,
              ),
            ),

            // Banner de permisos de notificación (amable, con memoria)
            if (_showNotificationBanner)
              SliverToBoxAdapter(
                child: NotificationPermissionBanner(
                  onAccept: () {
                    setState(() => _showNotificationBanner = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('¡Notificaciones activadas con éxito!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  onDismiss: () {
                    setState(() => _showNotificationBanner = false);
                  },
                ),
              ),

            // Banners promocionales interactivos
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8, bottom: 4),
                child: PromoBannerCarousel(),
              ),
            ),

            // Sección Destacados
            SliverToBoxAdapter(
              child: FeaturedMovieSlider(
                featuredMovies: featuredMovies,
                onMovieSelected: _onMovieSelected,
              ),
            ),

            // Sección Preventa
            if (presaleMovies.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Row(
                    children: [
                      const Text(
                        'PREVENTA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
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
                        child: Text(
                          '${presaleMovies.length} TÍTULOS',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 290,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: presaleMovies.length,
                    itemBuilder: (context, index) {
                      final movie = presaleMovies[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: MovieCard(
                          movie: movie,
                          currentCinemaId: _currentCinema.id,
                          onTap: () => _onMovieSelected(movie),
                          width: 140,
                          height: 200,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Sección Cartelera con Filtro de Usabilidad
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CARTELERA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        // Badge con total disponible
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '${billboardMovies.length} disponibles',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Filtro de Prevención de Errores (Nielsen #5)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _filterOnlyAvailable = !_filterOnlyAvailable;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _filterOnlyAvailable
                              ? AppColors.primaryLight
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _filterOnlyAvailable
                                ? AppColors.primary
                                : AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _filterOnlyAvailable
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 14,
                              color: _filterOnlyAvailable
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Mostrar solo con funciones en ${_currentCinema.city}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _filterOnlyAvailable
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Grid de películas de la cartelera
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final movie = billboardMovies[index];
                    return MovieCard(
                      movie: movie,
                      currentCinemaId: _currentCinema.id,
                      onTap: () => _onMovieSelected(movie),
                      width: double.infinity,
                      height: 200,
                    );
                  },
                  childCount: billboardMovies.length,
                ),
              ),
            ),

            // Espaciador inferior para no tapar con el navigation bar
            const SliverToBoxAdapter(
              child: SizedBox(height: 30),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentBottomNavIndex,
          onTap: (index) {
            setState(() => _currentBottomNavIndex = index);
            if (index == 4) {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.confirmation_number_outlined, color: AppColors.primary),
                          title: const Text('Mis Boletos y Compras'),
                          subtitle: const Text('Historial y códigos QR de tus entradas'),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PurchaseHistoryView()),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.science_outlined, color: AppColors.primary),
                          title: const Text('Panel de Investigador IHC'),
                          subtitle: const Text('Configurar sujeto, pre-test y métricas de tesis'),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ThesisPanelView()),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.info_outline, color: AppColors.primary),
                          title: const Text('Acerca del Prototipo'),
                          subtitle: const Text('Rediseño IHC Cinemark Perú - Tesis'),
                          onTap: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else if (index != 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Sección ${index == 1 ? 'Confitería' : index == 2 ? 'Cines' : 'Cinemark Club'} disponible',
                  ),
                  duration: const Duration(milliseconds: 900),
                ),
              );
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.movie_filter),
              label: 'Películas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fastfood_outlined),
              label: 'Confitería',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.apartment_outlined),
              label: 'Cines',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.card_membership),
              label: 'Club Fan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu),
              label: 'Menú',
            ),
          ],
        ),
      ),
    );
  }
}
