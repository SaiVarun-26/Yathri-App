/// How a trip was made.
///
/// Cost and emission factors are rough Indian-city averages and are intentionally
/// kept in one place so they can later be driven by remote config.
enum TransportMode {
  walking('Walking', 0, 0, 0),
  running('Running', 0, 0, 0),
  cycling('Cycle', 0, 0, 0),

  /// Motorcycle or scooter. One category because they move alike.
  bike('Bike / Scooter', 2.6, 0, 70),
  car('Car', 8.0, 0, 170),
  bus('Bus', 1.6, 10, 25),
  metro('Metro', 2.8, 10, 12),
  train('Train', 0.7, 10, 20),
  auto('Auto', 14.0, 30, 90),
  taxi('Taxi', 17.0, 60, 170),
  unknown('Unknown', 0, 0, 0);

  const TransportMode(this.label, this.costPerKm, this.baseFare, this.gramsCo2PerKm);

  final String label;

  /// Rupees per km (fuel for private vehicles, fare for public/for-hire).
  final double costPerKm;

  /// Minimum fare in rupees.
  final double baseFare;

  /// Tailpipe/operational grams CO2 per passenger-km.
  final double gramsCo2PerKm;

  bool get isGreen =>
      this == walking ||
      this == running ||
      this == cycling ||
      this == bus ||
      this == metro ||
      this == train;

  /// Human-powered.
  bool get isActive => this == walking || this == running || this == cycling;

  bool get isPublic => this == bus || this == metro || this == train;

  /// Modes that share the road, so their journey time is affected by traffic.
  bool get isRoadTraffic => this == car || this == bike || this == bus || this == auto || this == taxi;

  /// Fuel is bought by the traveller (as opposed to a fare paid per trip).
  bool get usesOwnFuel => this == car || this == bike;

  double estimateCost(double distanceKm) {
    if (costPerKm == 0) return 0;
    return baseFare + costPerKm * distanceKm;
  }

  static TransportMode fromName(String? name) =>
      TransportMode.values.firstWhere((m) => m.name == name, orElse: () => TransportMode.unknown);
}
