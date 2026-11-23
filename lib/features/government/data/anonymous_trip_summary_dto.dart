import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/zone.dart';
import '../domain/anonymous_trip_summary.dart';

abstract final class AnonymousTripSummaryDto {
  static Map<String, dynamic> toJson(AnonymousTripSummary s) => {
        'originZone': s.originZone.id,
        'destinationZone': s.destinationZone.id,
        'mode': s.mode.name,
        'distanceKm': s.distanceKm,
        'hour': s.hourStart.millisecondsSinceEpoch,
        'durationMin': s.durationMinutes,
      };

  static AnonymousTripSummary fromJson(Map<dynamic, dynamic> j) => AnonymousTripSummary(
        originZone: Zone.parse(j['originZone'] as String),
        destinationZone: Zone.parse(j['destinationZone'] as String),
        mode: TransportMode.fromName(j['mode'] as String?),
        distanceKm: (j['distanceKm'] as num).toDouble(),
        hourStart: DateTime.fromMillisecondsSinceEpoch((j['hour'] as num).toInt()),
        durationMinutes: (j['durationMin'] as num?)?.toInt() ?? 0,
      );
}
