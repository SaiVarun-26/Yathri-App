import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/mode_feedback.dart';

/// Keeps the user's mode corrections on the device. They never leave it.
class ModeFeedbackStore {
  static const _key = 'mode_feedback_v1';
  static const _maxEntries = 300;

  Future<List<ModeFeedback>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => ModeFeedback.fromJson(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// One entry per trip: correcting a trip again replaces the earlier answer.
  Future<List<ModeFeedback>> upsert(ModeFeedback feedback) async {
    final current = await load();
    final next = [
      for (final f in current)
        if (f.tripId != feedback.tripId) f,
      feedback,
    ];
    final trimmed = next.length > _maxEntries ? next.sublist(next.length - _maxEntries) : next;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(trimmed.map((f) => f.toJson()).toList()));
    return trimmed;
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
