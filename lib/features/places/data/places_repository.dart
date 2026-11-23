import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/place_book.dart';

/// Persists place names on the device only. Names never leave the phone.
class PlacesRepository {
  static const labelsKey = 'place_labels_v1';
  static const geocodedKey = 'place_geocoded_v1';

  Future<PlaceBook> load() async {
    final p = await SharedPreferences.getInstance();
    return PlaceBook(labels: _read(p, labelsKey), geocoded: _read(p, geocodedKey));
  }

  Future<void> save(PlaceBook book) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(labelsKey, jsonEncode(book.labels));
    await p.setString(geocodedKey, jsonEncode(book.geocoded));
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(labelsKey);
    await p.remove(geocodedKey);
  }

  Map<String, String> _read(SharedPreferences p, String key) {
    final raw = p.getString(key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry(k as String, v as String));
    } catch (_) {
      return {};
    }
  }
}
