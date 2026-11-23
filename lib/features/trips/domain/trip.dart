import 'package:flutter/foundation.dart';

import 'track_point.dart';
import 'transport_mode.dart';
import 'zone.dart';

/// A completed, detected trip. Immutable domain entity.
@immutable
class Trip {
  const Trip({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.mode,
    required this.modeConfidence,
    required this.distanceMeters,
    required this.maxSpeedMps,
    required this.movingSeconds,
    required this.route,
    required this.originZone,
    required this.destinationZone,
    required this.costInr,
    this.userCorrectedMode = false,
    this.sharedWithGovernment = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? endTime;

  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final TransportMode mode;
  final double modeConfidence;
  final double distanceMeters;
  final double maxSpeedMps;

  /// Seconds spent actually moving (excludes stops), for average speed.
  final int movingSeconds;

  /// Full-resolution route. Stays on the device; never uploaded.
  final List<TrackPoint> route;
  final Zone originZone;
  final Zone destinationZone;
  final double costInr;
  final bool userCorrectedMode;
  final bool sharedWithGovernment;
  /// Last modification time; used for last-writer-wins sync resolution.
  final DateTime updatedAt;

  /// Below this confidence the mode is shown as "Probably X".
  static const double confidentModeThreshold = 0.6;

  /// True when the app is guessing and the user has not confirmed the mode.
  bool get modeIsUncertain =>
      mode != TransportMode.unknown && !userCorrectedMode && modeConfidence < confidentModeThreshold;

  /// The mode as it should be written for the user: "Probably Bike / Scooter"
  /// when unsure, plain "Car" when confident or confirmed.
  String get modeText => modeIsUncertain ? 'Probably ${mode.label}' : mode.label;

  Duration get duration => endTime.difference(startTime);
  double get distanceKm => distanceMeters / 1000;

  double get avgSpeedKmh {
    if (movingSeconds <= 0) return 0;
    return (distanceMeters / movingSeconds) * 3.6;
  }

  double get maxSpeedKmh => maxSpeedMps * 3.6;

  double get co2Grams => mode.gramsCo2PerKm * distanceKm;

  /// CO2 avoided compared with making the same trip by car.
  double get co2SavedGrams {
    final saved = TransportMode.car.gramsCo2PerKm * distanceKm - co2Grams;
    return saved < 0 ? 0 : saved;
  }

  Trip copyWith({
    TransportMode? mode,
    double? modeConfidence,
    double? costInr,
    bool? userCorrectedMode,
    bool? sharedWithGovernment,
    DateTime? updatedAt,
  }) =>
      Trip(
        id: id,
        startTime: startTime,
        endTime: endTime,
        mode: mode ?? this.mode,
        modeConfidence: modeConfidence ?? this.modeConfidence,
        distanceMeters: distanceMeters,
        maxSpeedMps: maxSpeedMps,
        movingSeconds: movingSeconds,
        route: route,
        originZone: originZone,
        destinationZone: destinationZone,
        costInr: costInr ?? this.costInr,
        userCorrectedMode: userCorrectedMode ?? this.userCorrectedMode,
        sharedWithGovernment: sharedWithGovernment ?? this.sharedWithGovernment,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}
