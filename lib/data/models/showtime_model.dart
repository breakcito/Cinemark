class Showtime {
  final String id;
  final String movieId;
  final String cinemaId;
  final DateTime date;
  final String timeFormatted;
  final String roomName;
  final String format; // 2D, XD, D-BOX, 3D
  final String language; // Doblada, Subtitulada
  final int totalSeats;
  final int availableSeats;

  const Showtime({
    required this.id,
    required this.movieId,
    required this.cinemaId,
    required this.date,
    required this.timeFormatted,
    required this.roomName,
    required this.format,
    required this.language,
    required this.totalSeats,
    required this.availableSeats,
  });

  bool get isSoldOut => availableSeats <= 0;
  bool get isAlmostFull => availableSeats > 0 && availableSeats <= 10;

  String get availabilityBadge {
    if (isSoldOut) return 'Agotado';
    if (isAlmostFull) return '¡Últimos $availableSeats asientos!';
    return '$availableSeats disponibles';
  }
}
