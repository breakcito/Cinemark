class TicketType {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category; // 'Tarifas Destacadas', 'General', 'Beneficios Club'
  final bool isRecommended;
  final bool isMemberOnly;
  final int pointsBonus;

  const TicketType({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.category,
    this.isRecommended = false,
    this.isMemberOnly = false,
    this.pointsBonus = 0,
  });

  String get formattedPrice => 'S/ ${price.toStringAsFixed(2)}';
}

class RedeemedCouponTicket {
  final String id;
  final String parentBatchCode;
  final String title;
  final String description;
  final double price; // usually 0.0

  const RedeemedCouponTicket({
    required this.id,
    required this.parentBatchCode,
    required this.title,
    this.description = 'Canje válido para 1 entrada 2D',
    this.price = 0.0,
  });
}

class BatchCoupon {
  final String code;
  final String title;
  final String description;
  final int totalTickets;
  final List<RedeemedCouponTicket> generatedTickets;

  BatchCoupon({
    required this.code,
    required this.title,
    required this.description,
    required this.totalTickets,
    required this.generatedTickets,
  });
}
