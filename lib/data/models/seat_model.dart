enum SeatStatus {
  available,
  selected,
  occupied,
  wheelchair, // Espacio preferencial / silla de ruedas
  corridor,   // Pasillo / espacio vacío
}

class Seat {
  final String id; // Ej. 'F7'
  final String row; // Ej. 'F'
  final int number; // Ej. 7
  final SeatStatus status;

  const Seat({
    required this.id,
    required this.row,
    required this.number,
    required this.status,
  });

  bool get isSelectable =>
      status == SeatStatus.available || status == SeatStatus.wheelchair;

  Seat copyWith({
    String? id,
    String? row,
    int? number,
    SeatStatus? status,
  }) {
    return Seat(
      id: id ?? this.id,
      row: row ?? this.row,
      number: number ?? this.number,
      status: status ?? this.status,
    );
  }
}
