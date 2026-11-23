# Yathri

Automatic travel diary for citizens, anonymous mobility insight for planners (SIH25082).

## Run

```
flutter pub get
flutter run                          # citizen app (Android)
flutter run -t lib/admin_main.dart   # Government portal (demo data until Firebase is configured)
```

Without Firebase the citizen app runs fully on-device: trips are detected and stored locally and nothing is shared.

## Enable Firebase

1. `dart pub global activate flutterfire_cli`
2. `flutterfire configure` (overwrites `lib/firebase_options.dart`)
3. In the console enable Anonymous auth (citizens) and Email/Password (admins), create a Realtime Database.
4. Deploy `database.rules.json`.
5. Give an admin account the `admin` custom claim (Admin SDK: `setCustomUserClaims(uid, {admin: true})`).

## Architecture

```
lib/
  core/            theme, widgets, geo utils, firebase bootstrap
  features/<name>/ domain (pure Dart) · data (DTOs, sources, repositories) · services · providers · presentation
```

Feature set: auth, trips (detection engine, mode classifier, foreground service), diary, analytics (cost, insights),
rewards, milestones, reminders, alerts, transparency, settings, government (aggregation + portal).

## Privacy model

- Route and exact places: device only. Not even in the user's own cloud copy.
- Cloud copy (`users/{uid}/trips`): zone-level only, readable by that user only.
- Government (`gov/trips`): origin zone, destination zone, mode, distance (0.5 km), hour, duration (5 min). No user id. Opt-in, off by default.
- Portal suppresses any group with fewer than 5 trips.

## Transport mode detection

`ModeClassifier` compares nine movement measurements against a profile of each mode (walking, running, cycle,
bike/scooter, car, auto, bus, train): typical speed, fast-end speed, top speed, stops per km, time spent stopped,
acceleration, braking, sharp turns per km and speed steadiness. It combines them with how common each mode is and what
the user owns, and reports a confidence. Below 60% the app says "Probably X".

Corrections the user makes are stored on the phone (`ModeFeedbackStore`) with the journey's measurements, and
`ModeRefiner` uses them to adjust the guess for similar journeys when a trip is imported.

The profiles are hand-set from how each mode moves, not trained on real data. Tuning them against real labelled trips
is the main way to improve accuracy. Auto is the hardest mode to separate and is often shown as "Probably Bike / Bus / Car".

## Product features (all computed on the phone)

- Home: today's travel time, distance, fuel cost, carbon, time in traffic, eco score, and one smart insight.
- Diary: start and destination names, route preview, cost. Naming a place renames every trip to it.
- Insights: behaviour, money, time, environment, patterns, favourite places, monthly and yearly report (shareable picture).
- Rewards: XP levels, green streak, goals you can edit, monthly challenges, achievements.
- Privacy: score with reasons, stored data, upload history, download and delete my data.
- Smart commute: learns your regular departure times; the background service sends a "running late" notification.
- Fuel: enter mileage and fuel price; a service reminder appears after a set distance.

Area names use Android's geocoder with the centre of a ~1 km zone, never an exact position.
`flutter_local_notifications` is pinned to 22.x because 23.x needs compileSdk 37, which the current Android Gradle plugin does not support.
