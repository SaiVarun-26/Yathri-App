import 'package:flutter/foundation.dart';

import 'route_features.dart';
import 'transport_mode.dart';

/// One correction made by the user: "this journey, which looked like X, was
/// actually Y". Kept on the device and used to tune later guesses.
@immutable
class ModeFeedback {
  const ModeFeedback({
    required this.tripId,
    required this.features,
    required this.detected,
    required this.corrected,
    required this.atMs,
  });

  final String tripId;
  final RouteFeatures features;
  final TransportMode detected;
  final TransportMode corrected;
  final int atMs;

  Map<String, dynamic> toJson() => {
        'trip': tripId,
        'f': features.toJson(),
        'from': detected.name,
        'to': corrected.name,
        'at': atMs,
      };

  factory ModeFeedback.fromJson(Map<dynamic, dynamic> j) => ModeFeedback(
        tripId: j['trip'] as String,
        features: RouteFeatures.fromJson(j['f'] as Map),
        detected: TransportMode.fromName(j['from'] as String?),
        corrected: TransportMode.fromName(j['to'] as String?),
        atMs: (j['at'] as num).toInt(),
      );
}

/// What we know about the user's vehicles, which makes some answers likelier.
/// `null` means the user has not said.
@immutable
class ModeContext {
  const ModeContext({this.ownsBike, this.ownsCar});

  static const unknown = ModeContext();

  final bool? ownsBike;
  final bool? ownsCar;
}
