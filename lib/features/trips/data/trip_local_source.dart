import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'trip_dto.dart';

/// On-device persistence for trips. Swap for SQLite/Drift without touching
/// the repository if volume grows.
abstract interface class TripLocalSource {
  Future<List<TripDto>> readAll();
  Future<void> writeAll(List<TripDto> trips);
}

class FileTripLocalSource implements TripLocalSource {
  File? _file;

  Future<File> _resolve() async {
    final cached = _file;
    if (cached != null) return cached;
    final dir = await getApplicationDocumentsDirectory();
    return _file = File('${dir.path}/yathri_trips.json');
  }

  @override
  Future<List<TripDto>> readAll() async {
    final file = await _resolve();
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString()) as List;
      return raw.map((e) => TripDto.fromJson(e as Map)).toList();
    } on FormatException {
      return []; // corrupted file: start clean rather than crash
    }
  }

  @override
  Future<void> writeAll(List<TripDto> trips) async {
    final file = await _resolve();
    // Write to a temp file then rename, so a crash never leaves a half-written file.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(trips.map((t) => t.toLocalJson()).toList()), flush: true);
    await tmp.rename(file.path);
  }
}

/// A drop-box of trips detected by the background service.
///
/// The service isolate may outlive the UI isolate, so every detected trip is
/// written as its own file here. The UI imports and deletes them. One file per
/// trip means the two isolates never contend for the same file.
class PendingTripInbox {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/pending_trips');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<void> put(TripDto trip) async {
    final dir = await _dir();
    final tmp = File('${dir.path}/${trip.id}.tmp');
    await tmp.writeAsString(jsonEncode(trip.toLocalJson()), flush: true);
    await tmp.rename('${dir.path}/${trip.id}.json');
  }

  /// Reads waiting trips without removing them. Call [remove] only after
  /// they have been durably saved, so a crash cannot lose a trip.
  static Future<List<TripDto>> peek() async {
    final dir = await _dir();
    final result = <TripDto>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        result.add(TripDto.fromJson(jsonDecode(await entity.readAsString()) as Map));
      } on FormatException {
        await entity.delete(); // unreadable, discard
      }
    }
    return result;
  }

  static Future<void> remove(Iterable<String> ids) async {
    final dir = await _dir();
    for (final id in ids) {
      final f = File('${dir.path}/$id.json');
      if (await f.exists()) await f.delete();
    }
  }
}
