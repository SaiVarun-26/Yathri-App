import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/transparency_log.dart';

class TransparencyRepository {
  static const _key = 'transparency_logs_v1';
  static const _maxEntries = 300;

  Future<List<TransparencyLog>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List).map((e) => TransparencyLog.fromJson(e as Map));
      return list.toList()..sort((a, b) => b.time.compareTo(a.time));
    } on FormatException {
      return [];
    }
  }

  Future<List<TransparencyLog>> add(TransparencyLog log) async {
    final current = await load();
    final next = [log, ...current].take(_maxEntries).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next.map((l) => l.toJson()).toList()));
    return next;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
