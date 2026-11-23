import 'package:flutter/foundation.dart';

import '../../analytics/domain/period_stats.dart';
import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/trip.dart';

/// Which vehicles the user owns.
enum VehicleType {
  none('No vehicle'),
  bike('Bike or scooter'),
  car('Car'),
  both('Both');

  const VehicleType(this.label);
  final String label;

  bool get hasBike => this == bike || this == both;
  bool get hasCar => this == car || this == both;
}

/// The user's vehicles and fuel price. Defaults are typical Indian figures so
/// the app is useful before any setup.
@immutable
class FuelProfile {
  const FuelProfile({
    this.vehicleType = VehicleType.both,
    this.carKmpl = 14,
    this.bikeKmpl = 45,
    this.pricePerLitre = 105,
    this.serviceEveryKm = 3000,
    this.lastServiceMs,
    this.configured = false,
  });

  final VehicleType vehicleType;
  final double carKmpl;
  final double bikeKmpl;
  final double pricePerLitre;

  /// Distance between services. 0 turns the reminder off.
  final int serviceEveryKm;
  final int? lastServiceMs;

  /// True once the user has entered their own figures.
  final bool configured;

  FuelProfile copyWith({
    VehicleType? vehicleType,
    double? carKmpl,
    double? bikeKmpl,
    double? pricePerLitre,
    int? serviceEveryKm,
    int? lastServiceMs,
    bool? configured,
  }) =>
      FuelProfile(
        vehicleType: vehicleType ?? this.vehicleType,
        carKmpl: carKmpl ?? this.carKmpl,
        bikeKmpl: bikeKmpl ?? this.bikeKmpl,
        pricePerLitre: pricePerLitre ?? this.pricePerLitre,
        serviceEveryKm: serviceEveryKm ?? this.serviceEveryKm,
        lastServiceMs: lastServiceMs ?? this.lastServiceMs,
        configured: configured ?? this.configured,
      );
}

@immutable
class MaintenanceStatus {
  const MaintenanceStatus({required this.kmSinceService, required this.intervalKm});

  final double kmSinceService;
  final int intervalKm;

  bool get due => kmSinceService >= intervalKm;
  double get fraction => (kmSinceService / intervalKm).clamp(0.0, 1.0);
  double get kmLeft => (intervalKm - kmSinceService).clamp(0.0, double.infinity);
}

/// Fuel used and spent over one period.
@immutable
class FuelPeriod {
  const FuelPeriod({required this.costInr, required this.litres, required this.km});

  static const zero = FuelPeriod(costInr: 0, litres: 0, km: 0);

  final double costInr;
  final double litres;

  /// Distance driven or ridden in your own vehicle.
  final double km;
}

/// Fuel spend for every period the app shows, calculated once.
@immutable
class FuelSummary {
  const FuelSummary({
    required this.today,
    required this.week,
    required this.month,
    required this.year,
    required this.allTime,
    required this.lastMonthSoFar,
    required this.monthFaresInr,
  });

  final FuelPeriod today;
  final FuelPeriod week;
  final FuelPeriod month;
  final FuelPeriod year;

  /// Everything recorded so far.
  final FuelPeriod allTime;

  /// Last month, counted only up to the same day, to compare like with like.
  final FuelPeriod lastMonthSoFar;

  /// How this month's fuel spend compares with the same days last month:
  /// +0.2 means 20% more. Null when there is nothing to compare.
  double? get monthTrend =>
      lastMonthSoFar.costInr < 20 || month.costInr <= 0 ? null : month.costInr / lastMonthSoFar.costInr - 1;

  /// Bus, auto and taxi fares this month. Not fuel, but money out.
  final double monthFaresInr;

  factory FuelSummary.of(Iterable<Trip> trips, FuelProfile profile, DateTime now) {
    final list = trips.toList();
    final dayStart = DateRanges.startOfDay(now);
    final weekStart = DateRanges.startOfWeek(now);
    final monthStart = DateRanges.startOfMonth(now);
    final yearStart = DateTime(now.year);

    FuelPeriod period(DateTime from) =>
        FuelCalculator.period(list.where((t) => !t.startTime.isBefore(from)), profile);

    final prevStart = DateTime(now.year, now.month - 1);
    var prevCut = prevStart.add(now.difference(monthStart));
    if (prevCut.isAfter(monthStart)) prevCut = monthStart;
    final lastMonthSoFar = FuelCalculator.period(
      list.where((t) => !t.startTime.isBefore(prevStart) && t.startTime.isBefore(prevCut)),
      profile,
    );

    final monthTrips = list.where((t) => !t.startTime.isBefore(monthStart));
    return FuelSummary(
      today: period(dayStart),
      week: period(weekStart),
      month: period(monthStart),
      year: period(yearStart),
      allTime: FuelCalculator.period(list, profile),
      lastMonthSoFar: lastMonthSoFar,
      monthFaresInr: monthTrips.where((t) => !t.mode.usesOwnFuel).fold(0.0, (a, t) => a + t.costInr),
    );
  }
}

abstract final class FuelCalculator {
  /// Litres burned by a car or bike trip: distance divided by mileage.
  /// Zero for other modes.
  static double litres(Trip t, FuelProfile p) {
    return switch (t.mode) {
      TransportMode.car => t.distanceKm / p.carKmpl,
      TransportMode.bike => t.distanceKm / p.bikeKmpl,
      _ => 0,
    };
  }

  /// Fuel spend for one trip: litres used times the price per litre.
  static double fuelCost(Trip t, FuelProfile p) => litres(t, p) * p.pricePerLitre;

  /// What a trip cost the traveller: fuel from the profile for own vehicles,
  /// the estimated fare otherwise.
  static double tripCost(Trip t, FuelProfile p) =>
      t.mode.usesOwnFuel ? fuelCost(t, p) : t.costInr;

  static double totalFuel(Iterable<Trip> trips, FuelProfile p) =>
      trips.fold(0.0, (a, t) => a + fuelCost(t, p));

  static double totalCost(Iterable<Trip> trips, FuelProfile p) =>
      trips.fold(0.0, (a, t) => a + tripCost(t, p));

  static FuelPeriod period(Iterable<Trip> trips, FuelProfile p) {
    var cost = 0.0;
    var litres = 0.0;
    var km = 0.0;
    for (final t in trips) {
      if (!t.mode.usesOwnFuel) continue;
      litres += FuelCalculator.litres(t, p);
      cost += fuelCost(t, p);
      km += t.distanceKm;
    }
    return FuelPeriod(costInr: cost, litres: litres, km: km);
  }

  /// Distance driven or ridden in own vehicles since the last service.
  static MaintenanceStatus? maintenance(Iterable<Trip> trips, FuelProfile p) {
    final since = p.lastServiceMs;
    if (!p.configured || p.serviceEveryKm <= 0 || since == null) return null;
    final km = trips
        .where((t) => t.mode.usesOwnFuel && t.startTime.millisecondsSinceEpoch >= since)
        .fold<double>(0, (a, t) => a + t.distanceKm);
    return MaintenanceStatus(kmSinceService: km, intervalKm: p.serviceEveryKm);
  }
}
