import 'package:firebase_database/firebase_database.dart';

import 'trip_dto.dart';

abstract interface class TripRemoteSource {
  /// Emits true whenever the backend connection is (re)established.
  Stream<bool> get connection;
  Future<Map<String, TripDto>> fetchAll(String uid);
  Future<void> upsert(String uid, TripDto trip);
  Future<void> delete(String uid, String tripId);
  Future<void> deleteAll(String uid);
}

class FirebaseTripRemoteSource implements TripRemoteSource {
  FirebaseTripRemoteSource(this._db);
  final FirebaseDatabase _db;

  DatabaseReference _trips(String uid) => _db.ref('users/$uid/trips');

  @override
  Stream<bool> get connection =>
      _db.ref('.info/connected').onValue.map((e) => e.snapshot.value == true);

  @override
  Future<Map<String, TripDto>> fetchAll(String uid) async {
    final snap = await _trips(uid).get().timeout(const Duration(seconds: 15));
    final raw = snap.value;
    if (raw is! Map) return {};
    final out = <String, TripDto>{};
    raw.forEach((key, value) {
      if (value is Map) {
        try {
          // Cloud copies carry no route; map them with an empty one.
          out[key as String] = TripDto.fromJson({...value, 'id': key});
        } catch (_) {
          // Skip malformed records rather than failing the whole sync.
        }
      }
    });
    return out;
  }

  @override
  Future<void> upsert(String uid, TripDto trip) =>
      _trips(uid).child(trip.id).set(trip.toRemoteJson());

  @override
  Future<void> delete(String uid, String tripId) => _trips(uid).child(tripId).remove();

  @override
  Future<void> deleteAll(String uid) => _trips(uid).remove();
}
