# 🚀 Yathri
### Smart Travel Diary & Mobility Intelligence Platform

> **Automatic travel diary for citizens. Anonymous mobility insights for governments.**
>
> Developed for **Smart India Hackathon (SIH 2025)** – Problem Statement **SIH25082**

---

# 📖 Overview

Yathri is an intelligent travel diary that automatically detects, records and analyzes a user's daily journeys without requiring manual input.

The application provides users with personalized travel insights, fuel consumption estimates, travel history, eco scores and commute analytics while, with explicit user consent, anonymously sharing aggregated mobility patterns with government agencies for infrastructure planning.

The project is designed with a **Privacy First** approach where precise user location never leaves the device.

---

# ✨ Features

## 🚶 Automatic Trip Detection

- Automatic trip start & stop detection
- Background tracking
- Live GPS tracking
- Automatic route generation
- No manual interaction required

---

## 🚗 Transport Mode Detection

Automatically detects

- Walking
- Running
- Bicycle
- Motorcycle / Scooter
- Car
- Auto
- Bus
- Train

Uses multiple movement characteristics including

- Average speed
- Maximum speed
- Speed consistency
- Stop frequency
- Acceleration
- Braking
- Heading changes
- Distance travelled
- Trip duration

Low confidence predictions are displayed as

> Probably Bike

instead of showing incorrect classifications.

Users can manually correct transport modes to improve future predictions.

---

## 📒 Smart Travel Diary

Automatically records

- Start time
- End time
- Distance
- Duration
- Route preview
- Transport mode
- Estimated fuel cost

Trips are organized by day and can be viewed later.

---

## 📊 Personal Insights

Automatically generates

- Daily summary
- Weekly summary
- Monthly summary
- Yearly summary

Analytics include

- Total distance
- Total trips
- Total travel time
- Fuel expenditure
- Favourite transport
- Favourite places
- Most active day
- Most active hour
- Average commute
- Carbon footprint
- Eco score

---

## ⛽ Fuel Tracking

Users can configure

- Vehicle type
- Mileage (km/L)
- Fuel price

Yathri estimates

- Fuel consumed
- Trip cost
- Daily fuel expense
- Weekly fuel expense
- Monthly fuel expense
- Lifetime fuel expense

---

## 🏆 Rewards

- XP based progression
- Travel levels
- Achievements
- Monthly challenges
- Green streaks
- Eco goals

---

## 🔒 Privacy Dashboard

Users can see

- What data is stored
- What data is shared
- Upload history
- Privacy score
- Download personal data
- Delete personal data
- Enable/disable anonymous government sharing

---

## 🏛 Government Mobility Portal

A separate administrator portal provides planners with anonymized mobility analytics.

Includes

- Trip heatmaps
- Origin-Destination analysis
- Peak hour analysis
- Transport mode distribution
- Mobility demand trends
- Infrastructure planning insights

No personally identifiable information is visible.

---

# 🏗 Architecture

The application follows **Clean Architecture** with feature-first organization.

```
lib/
│
├── core/
│   ├── theme
│   ├── widgets
│   ├── geo
│   ├── firebase
│   └── utilities
│
├── features/
│   ├── auth
│   ├── trips
│   ├── diary
│   ├── analytics
│   ├── rewards
│   ├── milestones
│   ├── reminders
│   ├── transparency
│   ├── settings
│   └── government
```

Each feature contains

```
Domain
Data
Services
Providers
Presentation
```

---

# 🛠 Tech Stack

## Mobile

- Flutter
- Dart
- Material 3

## State Management

- Riverpod

## Architecture

- Clean Architecture
- Repository Pattern
- Feature-first Architecture
- Dependency Injection

## Backend

- Firebase Authentication
- Firebase Realtime Database

## Maps

- flutter_map
- OpenStreetMap

## Location

- Geolocator

## Background Tracking

- flutter_foreground_task

## Navigation

- go_router

## Local Storage

- JSON Storage
- path_provider

---

# 📱 Running the Project

## Install dependencies

```bash
flutter pub get
```

## Run Citizen Application

```bash
flutter run
```

## Run Government Portal

```bash
flutter run -t lib/admin_main.dart
```

---

# 🔥 Firebase Setup

1. Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

2. Configure Firebase

```bash
flutterfire configure
```

This generates

```
lib/firebase_options.dart
```

3. Enable

- Anonymous Authentication
- Email & Password Authentication
- Firebase Realtime Database

4. Deploy

```
database.rules.json
```

5. Create an administrator account

Assign

```
admin = true
```

using Firebase Admin SDK.

---

# 🔒 Privacy Model

## Stored only on device

- Exact route
- GPS coordinates
- Travel history
- User corrections

## Stored in user's cloud account

- Zone level trips
- Distance
- Duration
- Transport mode

## Shared with Government (Only with Consent)

- Origin zone
- Destination zone
- Mode
- Rounded distance
- Rounded duration
- Hour bucket

Never shared

- Name
- Phone number
- Email
- User ID
- Exact coordinates
- Route

The Government Portal hides any analytics group with fewer than **5 trips** to preserve anonymity.

---

# 🚘 Transport Mode Detection

The transport classifier uses multiple movement characteristics rather than relying only on speed.

Features include

- Average speed
- Top speed
- Speed consistency
- Stops per kilometre
- Time spent stationary
- Acceleration
- Braking
- Heading changes

User corrections are stored locally and reused to improve predictions for similar future trips.

---

# 📈 Future Improvements

- Machine Learning based transport classification
- Real-time traffic prediction
- Route recommendation
- Crowd density estimation
- Public transport integration
- Weather-aware travel insights
- Multi-device synchronization
- Offline map support

---

# 🎯 Smart India Hackathon

**Problem Statement**

**SIH25082**

Theme

**Smart Mobility & Urban Infrastructure**

---

# 👥 Team

**TechTactix**

---

# 📄 License

This project was developed as part of the **Smart India Hackathon (SIH)** and is intended for academic and demonstration purposes.
