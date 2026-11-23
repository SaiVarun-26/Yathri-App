import 'dart:async';

import '../domain/trip.dart';
import '../domain/trip_repository.dart';
import 'trip_dto.dart';
import 'trip_local_source.dart';
import 'trip_remote_source.dart';

class TripRepositoryImpl implements TripRepository {
  TripRepositoryImpl({
    required this._local,
    this._remote,
    String? Function()? cloudUid,
  }) : _cloudUid = cloudUid ?? (() => null);

  final TripLocalSource _local;
  final TripRemoteSource? _remote;
  final String? Function() _cloudUid;

  // Serialises read-modify-write cycles on the local file.
  Future<void> _queue = Future.value();

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  List<Trip> _sorted(Iterable<TripDto> dtos) =>
      dtos.map((d) => d.toDomain()).toList()..sort((a, b) => b.startTime.compareTo(a.startTime));

  @override
  Future<List<Trip>> loadAll() async => _sorted(await _local.readAll());

  @override
  Future<List<Trip>> importPending() => _exclusive(() async {
        final pending = await PendingTripInbox.peek();
        if (pending.isEmpty) return <Trip>[];
        final existing = {for (final d in await _local.readAll()) d.id: d};
        final added = <TripDto>[];
        for (final p in pending) {
          if (!existing.containsKey(p.id)) {
            existing[p.id] = p;
            added.add(p);
          }
        }
        await _local.writeAll(existing.values.toList());
        await PendingTripInbox.remove(pending.map((p) => p.id));
        return _sorted(added);
      });

  @override
  Future<void> save(Trip trip) => _exclusive(() async {
        final dto = TripDto.fromDomain(trip);
        final all = await _local.readAll();
        final index = all.indexWhere((d) => d.id == dto.id);
        if (index >= 0) {
          all[index] = dto;
        } else {
          all.add(dto);
        }
        await _local.writeAll(all);
        _pushQuietly(dto);
      });

  @override
  Future<void> delete(String id) => _exclusive(() async {
        final all = await _local.readAll();
        all.removeWhere((d) => d.id == id);
        await _local.writeAll(all);
        final uid = _cloudUid();
        if (uid != null) {
          unawaited(_remote?.delete(uid, id).catchError((_) {}));
        }
      });

  @override
  Future<void> deleteAll() => _exclusive(() async {
        await _local.writeAll(const []);
        final pending = await PendingTripInbox.peek();
        await PendingTripInbox.remove(pending.map((p) => p.id));
        final uid = _cloudUid();
        if (uid != null) {
          // Queued by offline persistence if there is no connection right now.
          unawaited(_remote?.deleteAll(uid).catchError((_) {}));
        }
      });

  void _pushQuietly(TripDto dto) {
    final uid = _cloudUid();
    if (uid == null || _remote == null) return;
    // With RTDB offline persistence the write is queued and flushed later.
    unawaited(_remote.upsert(uid, dto).catchError((_) {}));
  }

  @override
  Future<List<Trip>?> sync() => _exclusive(() async {
        final uid = _cloudUid();
        final remote = _remote;
        if (uid == null || remote == null) return null;

        final Map<String, TripDto> cloud;
        try {
          cloud = await remote.fetchAll(uid);
        } catch (_) {
          return null; // offline or permission problem; try again later
        }

        final local = {for (final d in await _local.readAll()) d.id: d};
        var changed = false;

        // Last-writer-wins per trip, keyed on updatedAt.
        for (final entry in cloud.entries) {
          final mine = local[entry.key];
          if (mine == null) {
            local[entry.key] = entry.value; // restored from cloud (no route)
            changed = true;
          } else if (entry.value.updatedMs > mine.updatedMs) {
            local[entry.key] = TripDto(
              id: mine.id,
              startMs: entry.value.startMs,
              endMs: entry.value.endMs,
              mode: entry.value.mode,
              confidence: entry.value.confidence,
              distanceM: entry.value.distanceM,
              maxSpeedMps: entry.value.maxSpeedMps,
              movingSeconds: entry.value.movingSeconds,
              originZone: entry.value.originZone,
              destinationZone: entry.value.destinationZone,
              costInr: entry.value.costInr,
              userCorrected: entry.value.userCorrected,
              shared: entry.value.shared || mine.shared,
              updatedMs: entry.value.updatedMs,
              route: mine.route, // never lose the on-device route
            );
            changed = true;
          } else if (entry.value.updatedMs < mine.updatedMs) {
            _pushQuietly(mine);
          }
        }
        for (final mine in local.values) {
          if (!cloud.containsKey(mine.id)) _pushQuietly(mine);
        }

        if (changed) await _local.writeAll(local.values.toList());
        return _sorted(local.values);
      });
}
