import 'package:firebase_database/firebase_database.dart';

import '../domain/anonymous_trip_summary.dart';
import 'anonymous_trip_summary_dto.dart';

abstract interface class GovTripUploader {
  Future<void> upload(AnonymousTripSummary summary);
}

/// Pushes to `gov/trips/{pushId}`. The key is random and contains no user id.
class FirebaseGovTripUploader implements GovTripUploader {
  FirebaseGovTripUploader(this._db);
  final FirebaseDatabase _db;

  @override
  Future<void> upload(AnonymousTripSummary summary) async {
    final ref = _db.ref('gov/trips').push();
    // Do not wait indefinitely when offline: RTDB persistence has queued it.
    await ref.set(AnonymousTripSummaryDto.toJson(summary)).timeout(
          const Duration(seconds: 6),
          onTimeout: () {},
        );
  }
}
