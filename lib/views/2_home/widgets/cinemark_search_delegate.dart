import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_data.dart';
import '../../../data/models/cinema_model.dart';
import '../../../data/models/purchase_session.dart';
import '../../3_showtimes/showtimes_view.dart';
import '../../6_concessions/concessions_view.dart';

class CinemarkSearchDelegate extends SearchDelegate<String?> {
  final Cinema currentCinema;
  final Function(Cinema) onCinemaSelected;

  CinemarkSearchDelegate({
    required this.currentCinema,
    required this.onCinemaSelected,
  }) : super(
          searchFieldLabel: 'Buscar películas, confitería, cines...',
          searchFieldStyle: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, size: 20),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final cleanQuery = query.trim().toLowerCase();

    final allMovies = MockData.getMovies();
    final allConcessions = MockData.getConcessionItems();
    final allCinemas = MockData.cinemas;

    final matchedMovies = cleanQuery.isEmpty
        ? allMovies.take(3).toList()
        : allMovies
            .where((m) =>
                m.title.toLowerCase().contains(cleanQuery) ||
                m.genre.toLowerCase().contains(cleanQuery) ||
                m.formats.any((f) => f.toLowerCase().contains(cleanQuery)))
            .toList();

    final matchedConcessions = cleanQuery.isEmpty
        ? allConcessions.take(2).toList()
        : allConcessions
            .where((c) =>
                c.name.toLowerCase().contains(cleanQuery) ||
                c.category.toLowerCase().contains(cleanQuery))
            .toList();

    final matchedCinemas = cleanQuery.isEmpty
        ? <Cinema>[]
        : allCinemas
            .where((c) =>
                c.name.toLowerCase().contains(cleanQuery) ||
                c.city.toLowerCase().contains(cleanQuery))
            .toList();

    if (cleanQuery.isNotEmpty &&
        matchedMovies.isEmpty &&
        matchedConcessions.isEmpty &&
        matchedCinemas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No encontramos resultados para "$query"',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Intenta buscar por título de película, combos o nombre de ciudad',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (cleanQuery.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'SUGERENCIAS POPULARES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],

        // Películas
        if (matchedMovies.isNotEmpty) ...[
          _buildSectionHeader('PELÍCULAS EN CARTELERA', Icons.movie_outlined),
          ...matchedMovies.map((movie) => ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    movie.posterUrl,
                    width: 38,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 38,
                      height: 54,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.movie, size: 18),
                    ),
                  ),
                ),
                title: Text(
                  movie.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${movie.genre} • ${movie.duration} • ${movie.rating}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  close(context, movie.title);
                  PurchaseSession().selectMovie(movie);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ShowtimesView(movie: movie),
                    ),
                  );
                },
              )),
        ],

        // Confitería
        if (matchedConcessions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSectionHeader('CONFITERÍA Y COMBOS', Icons.fastfood_outlined),
          ...matchedConcessions.map((item) => ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(item.iconEmoji, style: const TextStyle(fontSize: 18)),
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  item.category,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                trailing: Text(
                  item.formattedPrice,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                onTap: () {
                  close(context, item.name);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ConcessionsView(),
                    ),
                  );
                },
              )),
        ],

        // Cines
        if (matchedCinemas.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSectionHeader('COMPLEJOS CINEMARK', Icons.location_city),
          ...matchedCinemas.map((cinema) => ListTile(
                leading: const Icon(Icons.apartment, color: AppColors.primary),
                title: Text(
                  cinema.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  cinema.city,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                trailing: currentCinema.id == cinema.id
                    ? const Chip(
                        label: Text('Activo', style: TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                      )
                    : const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  onCinemaSelected(cinema);
                  close(context, cinema.name);
                },
              )),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
