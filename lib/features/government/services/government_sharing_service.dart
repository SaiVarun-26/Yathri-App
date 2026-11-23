import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../transparency/data/transparency_repository.dart';
import '../../transparency/domain/transparency_log.dart';
import '../../trips/domain/trip.dart';
import '../data/gov_trip_uploader.dart';
import '../domain/anonymous_trip_summary.dart';

/// Decides what leaves the device for each finished trip, uploads only the
/// anonymous summary (when the user has consented), and records every
/// decision in the transparency log.
class GovernmentSharingService {
  GovernmentSharingService({
    required this._transparency,
    this._uploader,
  });

  final TransparencyRepository _transparency;
  final GovTripUploader? _uploader;
  static const _uuid = Uuid();

  /// Processes a new trip. Returns the trip with its shared flag updated, plus
  /// the refreshed transparency log list.
  Future<({Trip trip, List<TransparencyLog> logs})> process(
    Trip trip, {
    required bool consented,
    bool logKept = true,
  }) async {
    var updated = trip;
    var logs = await _transparency.load();
    final when = DateFormat('d MMM, h:mm a').format(trip.startTime);

    if (logKept) {
      logs = await _transparency.add(TransparencyLog(
        id: _uuid.v4(),
        time: DateTime.now(),
        kind: TransparencyKind.keptOnDevice,
        title: 'Trip kept on your phone',
        detail: 'Your exact route and places for the $when trip never left this device.',
        tripId: trip.id,
        fields: const ['Exact GPS route', 'Exact start and end points'],
      ));
    }

    final uploader = _uploader;
    if (consented && uploader != null && !trip.sharedWithGovernment) {
      try {
        final summary = AnonymousTripSummary.fromTrip(trip);
        await uploader.upload(summary);
        updated = trip.copyWith(sharedWithGovernment: true);
        logs = await _transparency.add(TransparencyLog(
          id: _uuid.v4(),
          time: DateTime.now(),
          kind: TransparencyKind.sharedAnonymous,
          title: 'Anonymous summary shared',
          detail:
              'Zones ${summary.originZone} → ${summary.destinationZone}, ${summary.mode.label}, '
              '${summary.distanceKm.toStringAsFixed(1)} km, around ${DateFormat('h a').format(summary.hourStart)}. '
              'Why: you allowed anonymous sharing, and this helps plan buses, roads and parking.',
          tripId: trip.id,
          fields: const [
            'Origin zone',
            'Destination zone',
            'Mode',
            'Distance',
            'Time (hour)',
          ],
        ));
      } catch (_) {
        // Leave unshared; it is retried the next time sharing is processed.
      }
    }
    return (trip: updated, logs: logs);
  }
}
