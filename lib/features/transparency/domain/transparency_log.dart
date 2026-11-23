import 'package:flutter/foundation.dart';

enum TransparencyKind {
  /// Anonymous summary sent to the Government.
  sharedAnonymous,

  /// Data intentionally kept on the phone.
  keptOnDevice,

  /// Private backup to the user's own cloud account.
  syncedToAccount,
}

@immutable
class TransparencyLog {
  const TransparencyLog({
    required this.id,
    required this.time,
    required this.kind,
    required this.title,
    required this.detail,
    this.tripId,
    this.fields = const [],
  });

  final String id;
  final DateTime time;
  final TransparencyKind kind;
  final String title;
  final String detail;
  final String? tripId;

  /// Names of the data fields involved, so the user can see exactly what moved.
  final List<String> fields;

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.millisecondsSinceEpoch,
        'kind': kind.name,
        'title': title,
        'detail': detail,
        'tripId': tripId,
        'fields': fields,
      };

  factory TransparencyLog.fromJson(Map<dynamic, dynamic> j) => TransparencyLog(
        id: j['id'] as String,
        time: DateTime.fromMillisecondsSinceEpoch((j['time'] as num).toInt()),
        kind: TransparencyKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => TransparencyKind.keptOnDevice,
        ),
        title: j['title'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
        tripId: j['tripId'] as String?,
        fields: ((j['fields'] as List?) ?? const []).cast<String>(),
      );
}
