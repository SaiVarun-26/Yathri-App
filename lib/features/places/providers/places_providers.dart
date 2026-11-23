import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../../trips/domain/zone.dart';
import '../../trips/providers/trip_providers.dart';
import '../data/places_repository.dart';
import '../domain/place_book.dart';

final placesRepositoryProvider = Provider((ref) => PlacesRepository());

class PlacesNotifier extends AsyncNotifier<PlaceBook> {
  final _geocoder = Geocoding();
  final _attempted = <String>{};
  bool _geocoding = false;

  @override
  Future<PlaceBook> build() => ref.watch(placesRepositoryProvider).load();

  /// Names a place, or clears the name when [name] is blank.
  Future<void> rename(Zone zone, String? name) async {
    final book = state.value ?? await future;
    final labels = {...book.labels};
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      labels.remove(zone.id);
    } else {
      labels[zone.id] = trimmed;
    }
    final next = book.copyWith(labels: labels);
    state = AsyncData(next);
    await ref.read(placesRepositoryProvider).save(next);
  }

  /// Looks up area names for zones that have none. Uses the zone centre
  /// (about 1 km precision), never an exact position. Failures (offline, no
  /// geocoder) are ignored and retried next launch.
  Future<void> geocodeMissing(Iterable<Zone> zones) async {
    if (_geocoding) return;
    _geocoding = true;
    try {
      var book = state.value ?? await future;
      for (final zone in zones) {
        if (_attempted.contains(zone.id)) continue;
        _attempted.add(zone.id);
        try {
          final marks = await _geocoder.placemarkFromCoordinates(zone.centerLat, zone.centerLng)
              .timeout(const Duration(seconds: 8));
          final name = _pickName(marks);
          if (name == null) continue;
          book = book.copyWith(geocoded: {...book.geocoded, zone.id: name});
          state = AsyncData(book);
        } catch (e) {
          debugPrint('Geocoding ${zone.id} failed: $e');
        }
      }
      await ref.read(placesRepositoryProvider).save(book);
    } finally {
      _geocoding = false;
    }
  }

  String? _pickName(List<Placemark> marks) {
    for (final m in marks) {
      for (final candidate in [m.subLocality, m.locality, m.subAdministrativeArea]) {
        if (candidate != null && candidate.trim().isNotEmpty) return candidate.trim();
      }
    }
    return null;
  }
}

final placesProvider = AsyncNotifierProvider<PlacesNotifier, PlaceBook>(PlacesNotifier.new);

/// Single place to turn a zone into a human name. Recomputes when trips or
/// names change.
final placeNamerProvider = Provider<PlaceNamer>((ref) {
  final book = ref.watch(placesProvider).value ?? const PlaceBook();
  final trips = ref.watch(tripListProvider);
  return PlaceNamer(book: book, inferred: PlaceInference.infer(trips));
});

/// Side-effect provider: fetches area names for the most visited unnamed
/// zones. Watched once from the app shell.
final placeGeocoderProvider = Provider<void>((ref) {
  final trips = ref.watch(tripListProvider);
  final book = ref.watch(placesProvider).value;
  if (book == null || trips.isEmpty) return;

  final visits = <Zone, int>{};
  for (final t in trips) {
    visits[t.originZone] = (visits[t.originZone] ?? 0) + 1;
    visits[t.destinationZone] = (visits[t.destinationZone] ?? 0) + 1;
  }
  final missing = (visits.keys.where((z) => !book.labels.containsKey(z.id) && !book.geocoded.containsKey(z.id)).toList()
        ..sort((a, b) => visits[b]!.compareTo(visits[a]!)))
      .take(8)
      .toList();
  if (missing.isEmpty) return;

  // Defer so provider state is never modified while building.
  Future.microtask(() => ref.read(placesProvider.notifier).geocodeMissing(missing));
});
