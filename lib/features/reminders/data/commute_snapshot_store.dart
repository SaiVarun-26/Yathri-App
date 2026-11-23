import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/commute_alert.dart';

/// Shares the user's regular journeys with the background service through
/// SharedPreferences (the two run in separate isolates).
class CommuteSnapshotStore {
  static const _routesKey = 'commute_routes_v1';
  static const _alertedKey = 'commute_alerted_v1';

  Future<void> saveRoutes(List<CommuteRoute> routes) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_routesKey, jsonEncode(routes.map((r) => r.toJson()).toList()));
  }

  /// [fresh] re-reads from disk; needed in the service isolate, which does
  /// not see writes made by the UI isolate otherwise.
  Future<List<CommuteRoute>> loadRoutes({bool fresh = false}) async {
    final p = await SharedPreferences.getInstance();
    if (fresh) await p.reload();
    final raw = p.getString(_routesKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => CommuteRoute.fromJson(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Set<String>> loadAlerted() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_alertedKey) ?? const []).toSet();
  }

  Future<void> markAlerted(String key) async {
    final p = await SharedPreferences.getInstance();
    final list = (p.getStringList(_alertedKey) ?? <String>[])..add(key);
    // Keep only the most recent keys; they are only needed for today.
    await p.setStringList(_alertedKey, list.length > 20 ? list.sublist(list.length - 20) : list);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_routesKey);
    await p.remove(_alertedKey);
  }
}
