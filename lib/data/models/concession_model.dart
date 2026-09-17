class ConcessionItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final double memberPrice;
  final String category;
  final String iconEmoji;
  final bool isAvailable;
  final bool isPopular;
  final double? savings;

  const ConcessionItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.memberPrice,
    required this.category,
    required this.iconEmoji,
    this.isAvailable = true,
    this.isPopular = false,
    this.savings,
  });

  double get effectivePrice => price;
  String get formattedPrice => 'S/ ${price.toStringAsFixed(2)}';
  double getDiscountedPrice(bool isMember) => isMember ? memberPrice : price;
}
