import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../fuel/providers/fuel_providers.dart';
import '../data/mode_feedback_store.dart';
import '../domain/mode_feedback.dart';
import '../domain/route_features.dart';
import '../domain/transport_mode.dart';
import '../domain/trip.dart';
import '../services/mode_classifier.dart';

final modeFeedbackStoreProvider = Provider((ref) => ModeFeedbackStore());

/// What the user owns, which makes some modes likelier than others. Unknown
/// until the user has told us in setup.
final modeContextProvider = Provider<ModeContext>((ref) {
  final profile = ref.watch(fuelProfileValueProvider);
  if (!profile.configured) return ModeContext.unknown;
  return ModeContext(ownsBike: profile.vehicleType.hasBike, ownsCar: profile.vehicleType.hasCar);
});

/// Applies the user's own past corrections and vehicle information on top of
/// the detector's first guess. Runs on the phone, when a trip is imported.
class ModeRefiner {
  const ModeRefiner({required this.feedbackStore, required this.context});

  final ModeFeedbackStore feedbackStore;
  final ModeContext context;

  Future<List<Trip>> refine(List<Trip> trips) async {
    final feedback = await feedbackStore.load();
    final classifier = ModeClassifier(feedback: feedback, context: context);
    return [for (final t in trips) _refineOne(classifier, t)];
  }

  Trip _refineOne(ModeClassifier classifier, Trip t) {
    if (t.userCorrectedMode || t.route.length < 3) return t;
    final result = classifier.classify(t.route);
    if (result.mode == TransportMode.unknown) return t;
    return t.copyWith(
      mode: result.mode,
      modeConfidence: result.confidence,
      costInr: result.mode.estimateCost(t.distanceKm),
      updatedAt: t.updatedAt,
    );
  }

  /// Stores a correction as a labelled example for future guesses.
  Future<void> recordCorrection(Trip before, TransportMode corrected) async {
    if (before.route.length < 3) return;
    final features = const ModeClassifier().extractFeatures(before.route);
    if (features == RouteFeatures.empty || features.movingSamples < 3) return;
    await feedbackStore.upsert(ModeFeedback(
      tripId: before.id,
      features: features,
      detected: before.mode,
      corrected: corrected,
      atMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }
}

final modeRefinerProvider = Provider<ModeRefiner>((ref) => ModeRefiner(
      feedbackStore: ref.watch(modeFeedbackStoreProvider),
      context: ref.watch(modeContextProvider),
    ));
