class OrderTicketItem {
  final String name;
  final int quantity;
  final double unitPrice;

  const OrderTicketItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;
}

class OrderConcessionItem {
  final String name;
  final int quantity;
  final double unitPrice;

  const OrderConcessionItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;
}

class CompletedOrder {
  final String orderCode;
  final DateTime purchaseDate;
  final String movieTitle;
  final String moviePosterUrl;
  final String movieClassification;
  final String movieDuration;
  final String cinemaName;
  final String cinemaAddress;
  final DateTime showtimeDate;
  final String showtimeHour;
  final String roomName;
  final String format;
  final String language;
  final List<String> seats;
  final List<OrderTicketItem> tickets;
  final List<OrderConcessionItem> concessions;
  final double totalAmount;
  final String paymentMethod;
  final String buyerName;
  final String buyerDni;
  final String buyerEmail;
  final String qrCodeData;
  final bool isUpcoming;

  CompletedOrder({
    required this.orderCode,
    required this.purchaseDate,
    required this.movieTitle,
    required this.moviePosterUrl,
    required this.movieClassification,
    required this.movieDuration,
    required this.cinemaName,
    required this.cinemaAddress,
    required this.showtimeDate,
    required this.showtimeHour,
    required this.roomName,
    required this.format,
    required this.language,
    required this.seats,
    required this.tickets,
    required this.concessions,
    required this.totalAmount,
    required this.paymentMethod,
    required this.buyerName,
    required this.buyerDni,
    required this.buyerEmail,
    required this.qrCodeData,
    this.isUpcoming = true,
  });
}
