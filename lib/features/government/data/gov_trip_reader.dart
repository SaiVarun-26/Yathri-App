import 'package:firebase_database/firebase_database.dart';

import '../domain/anonymous_trip_summary.dart';
import 'anonymous_trip_summary_dto.dart';

/// Admin-side read access to anonymous summaries. Security rules restrict
/// `gov/` reads to accounts with the `admin` custom claim.
class GovTripReader {
  GovTripReader(this._db, {this.limit = 5000});
  final FirebaseDatabase _db;
  final int limit;

  Stream<List<AnonymousTripSummary>> watch() {
    return _db.ref('gov/trips').orderByChild('hour').limitToLast(limit).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return const <AnonymousTripSummary>[];
      final out = <AnonymousTripSummary>[];
      for (final v in raw.values) {
        if (v is! Map) continue;
        try {
          out.add(AnonymousTripSummaryDto.fromJson(v));
        } catch (_) {
          // Ignore malformed records.
        }
      }
      return out;
    });
  }
}
