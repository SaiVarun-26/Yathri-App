import '../domain/track_point.dart';
import '../domain/transport_mode.dart';
import '../domain/trip.dart';
import '../domain/zone.dart';

/// Serialisable representation of a [Trip]. Keeps JSON concerns out of the
/// domain layer.
class TripDto {
  const TripDto({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.mode,
    required this.confidence,
    required this.distanceM,
    required this.maxSpeedMps,
    required this.movingSeconds,
    required this.originZone,
    required this.destinationZone,
    required this.costInr,
    required this.userCorrected,
    required this.shared,
    required this.updatedMs,
    required this.route,
  });

  final String id;
  final int startMs;
  final int endMs;
  final String mode;
  final double confidence;
  final double distanceM;
  final double maxSpeedMps;
  final int movingSeconds;
  final String originZone;
  final String destinationZone;
  final double costInr;
  final bool userCorrected;
  final bool shared;
  final int updatedMs;
  final List<Map<String, dynamic>> route;

  factory TripDto.fromDomain(Trip t) => TripDto(
        id: t.id,
        startMs: t.startTime.millisecondsSinceEpoch,
        endMs: t.endTime.millisecondsSinceEpoch,
        mode: t.mode.name,
        confidence: t.modeConfidence,
        distanceM: t.distanceMeters,
        maxSpeedMps: t.maxSpeedMps,
        movingSeconds: t.movingSeconds,
        originZone: t.originZone.id,
        destinationZone: t.destinationZone.id,
        costInr: t.costInr,
        userCorrected: t.userCorrectedMode,
        shared: t.sharedWithGovernment,
        updatedMs: t.updatedAt.millisecondsSinceEpoch,
        route: t.route.map((p) => p.toJson()).toList(growable: false),
      );

  factory TripDto.fromJson(Map<dynamic, dynamic> j) => TripDto(
        id: j['id'] as String,
        startMs: (j['start'] as num).toInt(),
        endMs: (j['end'] as num).toInt(),
        mode: j['mode'] as String? ?? 'unknown',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        distanceM: (j['distanceM'] as num).toDouble(),
        maxSpeedMps: (j['maxSpeedMps'] as num?)?.toDouble() ?? 0,
        movingSeconds: (j['movingSeconds'] as num?)?.toInt() ?? 0,
        originZone: j['originZone'] as String,
        destinationZone: j['destinationZone'] as String,
        costInr: (j['costInr'] as num?)?.toDouble() ?? 0,
        userCorrected: j['userCorrected'] as bool? ?? false,
        shared: j['shared'] as bool? ?? false,
        updatedMs: (j['updated'] as num?)?.toInt() ?? (j['end'] as num).toInt(),
        route: ((j['route'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false),
      );

  Trip toDomain() => Trip(
        id: id,
        startTime: DateTime.fromMillisecondsSinceEpoch(startMs),
        endTime: DateTime.fromMillisecondsSinceEpoch(endMs),
        mode: TransportMode.fromName(mode),
        modeConfidence: confidence,
        distanceMeters: distanceM,
        maxSpeedMps: maxSpeedMps,
        movingSeconds: movingSeconds,
        route: route.map(TrackPoint.fromJson).toList(growable: false),
        originZone: Zone.parse(originZone),
        destinationZone: Zone.parse(destinationZone),
        costInr: costInr,
        userCorrectedMode: userCorrected,
        sharedWithGovernment: shared,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMs),
      );

  Map<String, dynamic> _base() => {
        'id': id,
        'start': startMs,
        'end': endMs,
        'mode': mode,
        'confidence': confidence,
        'distanceM': distanceM,
        'maxSpeedMps': maxSpeedMps,
        'movingSeconds': movingSeconds,
        'originZone': originZone,
        'destinationZone': destinationZone,
        'costInr': costInr,
        'userCorrected': userCorrected,
        'shared': shared,
        'updated': updatedMs,
      };

  /// Full record including the GPS route. Device storage only.
  Map<String, dynamic> toLocalJson() => {..._base(), 'route': route};

  /// Cloud record. The GPS route is deliberately omitted: only zone-level
  /// location is ever synced, even to the user's own cloud account.
  Map<String, dynamic> toRemoteJson() => _base();
}
