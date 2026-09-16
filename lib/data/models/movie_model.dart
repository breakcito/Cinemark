import 'showtime_model.dart';

class Movie {
  final String id;
  final String title;
  final String posterUrl;
  final String backdropUrl;
  final String rating; // APT, M14, +18
  final String ratingDescription; // Apto para todo Público, Mayores de 14 años
  final String duration; // 2H 30M
  final String genre; // Acción, Documental, Anime, etc.
  final String synopsis;
  final String director;
  final String cast;
  final List<String> formats; // 2D, XD, D-BOX, 3D
  final bool isPresale;
  final bool isFeatured;
  final bool isNowPlaying;
  final bool isComingSoon;
  final String releaseBadge; // "ESTRENO", "Re-Estreno", "20 DE AGOSTO"
  final String trailerUrl;
  final List<Showtime> showtimes;

  const Movie({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.backdropUrl,
    required this.rating,
    required this.ratingDescription,
    required this.duration,
    required this.genre,
    required this.synopsis,
    required this.director,
    required this.cast,
    required this.formats,
    this.isPresale = false,
    this.isFeatured = false,
    this.isNowPlaying = false,
    this.isComingSoon = false,
    this.releaseBadge = '',
    this.trailerUrl = '',
    this.showtimes = const [],
  });

  bool hasShowtimesInCinema(String cinemaId) {
    return showtimes.any((st) => st.cinemaId == cinemaId && !st.isSoldOut);
  }

  List<Showtime> getShowtimesForDateAndCinema(DateTime date, String cinemaId) {
    return showtimes.where((st) {
      final isSameDate = st.date.year == date.year &&
          st.date.month == date.month &&
          st.date.day == date.day;
      return isSameDate && st.cinemaId == cinemaId;
    }).toList();
  }
}
