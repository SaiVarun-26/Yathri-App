import 'package:firebase_database/firebase_database.dart';

import '../domain/local_alert.dart';

/// Reads public alerts published by authorities at `alerts/`.
class FirebaseAlertsRepository implements AlertsRepository {
  FirebaseAlertsRepository(this._db);
  final FirebaseDatabase _db;

  @override
  Stream<List<LocalAlert>> watch() {
    return _db.ref('alerts').orderByChild('issuedAt').limitToLast(30).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return const <LocalAlert>[];
      final alerts = <LocalAlert>[];
      raw.forEach((key, value) {
        if (value is! Map) return;
        final issued = (value['issuedAt'] as num?)?.toInt();
        if (issued == null) return;
        alerts.add(LocalAlert(
          id: key as String,
          type: AlertType.values.firstWhere(
            (t) => t.name == value['type'],
            orElse: () => AlertType.roadClosure,
          ),
          title: value['title'] as String? ?? 'Alert',
          message: value['message'] as String? ?? '',
          issuedAt: DateTime.fromMillisecondsSinceEpoch(issued),
          expiresAt: (value['expiresAt'] as num?) == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch((value['expiresAt'] as num).toInt()),
        ));
      });
      alerts.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
      return alerts;
    });
  }
}
