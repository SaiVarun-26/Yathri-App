import 'package:flutter/foundation.dart';

enum AlertType { roadClosure, weather, construction, festival, tourism }

@immutable
class LocalAlert {
  const LocalAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.issuedAt,
    this.expiresAt,
  });

  final String id;
  final AlertType type;
  final String title;
  final String message;
  final DateTime issuedAt;
  final DateTime? expiresAt;

  bool isActive(DateTime now) => expiresAt == null || expiresAt!.isAfter(now);
}

abstract interface class AlertsRepository {
  Stream<List<LocalAlert>> watch();
}

/// Used in local-only mode.
class EmptyAlertsRepository implements AlertsRepository {
  @override
  Stream<List<LocalAlert>> watch() => Stream.value(const []);
}
