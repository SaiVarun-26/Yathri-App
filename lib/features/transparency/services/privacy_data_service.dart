import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../fuel/data/fuel_repository.dart';
import '../../places/data/places_repository.dart';
import '../../reminders/data/commute_snapshot_store.dart';
import '../../rewards/data/goals_repository.dart';
import '../../trips/data/mode_feedback_store.dart';
import '../../trips/data/trip_dto.dart';
import '../../trips/domain/trip_repository.dart';
import '../data/transparency_repository.dart';

/// "Download my data" and "Delete my data".
class PrivacyDataService {
  PrivacyDataService({
    required this._trips,
    required this._transparency,
    required this._places,
    required this._fuel,
    required this._goals,
    required this._commute,
    required this._modeFeedback,
  });

  final TripRepository _trips;
  final TransparencyRepository _transparency;
  final PlacesRepository _places;
  final FuelRepository _fuel;
  final GoalsRepository _goals;
  final CommuteSnapshotStore _commute;
  final ModeFeedbackStore _modeFeedback;

  /// Writes everything the app holds about the user to one JSON file and
  /// returns it, ready to share or save.
  Future<File> exportAll() async {
    final trips = await _trips.loadAll();
    final logs = await _transparency.load();
    final places = await _places.load();
    final fuel = await _fuel.load();
    final goals = await _goals.load();
    final corrections = await _modeFeedback.load();

    final data = {
      'exportedAt': DateTime.now().toIso8601String(),
      'about': 'Everything Yathri stores about you. Routes are included here and stay on your phone otherwise.',
      'trips': trips.map((t) => TripDto.fromDomain(t).toLocalJson()).toList(),
      'placeNames': places.labels,
      'modeCorrections': corrections.map((c) => c.toJson()).toList(),
      'activityLog': logs.map((l) => l.toJson()).toList(),
      'vehicle': {
        'carKmPerLitre': fuel.carKmpl,
        'bikeKmPerLitre': fuel.bikeKmpl,
        'fuelPricePerLitre': fuel.pricePerLitre,
        'serviceEveryKm': fuel.serviceEveryKm,
      },
      'goals': {
        'walkKmPerWeek': goals.walkKmPerWeek,
        'cycleKmPerWeek': goals.cycleKmPerWeek,
        'fuelBudgetPerMonth': goals.fuelBudgetPerMonth,
        'ecoScoreTarget': goals.ecoScoreTarget,
      },
    };

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${dir.path}/yathri-my-data-$stamp.json');
    return file.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);
  }

  /// Erases trips (device and cloud backup), the activity log, place names,
  /// vehicle details, goals and reminder data.
  ///
  /// Anonymous summaries already sent to the Government carry no identifier,
  /// so they cannot be traced back to this user and cannot be removed.
  Future<void> deleteAll() async {
    await _trips.deleteAll();
    await _transparency.clear();
    await _places.clear();
    await _fuel.clear();
    await _goals.clear();
    await _commute.clear();
    await _modeFeedback.clear();
  }
}
