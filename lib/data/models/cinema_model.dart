class Cinema {
  final String id;
  final String name;
  final String city;
  final String address;
  final bool isRecommended;
  final double distanceKm;

  const Cinema({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    this.isRecommended = false,
    this.distanceKm = 1.2,
  });
}
