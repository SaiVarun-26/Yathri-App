import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/presentation/insights_screen.dart';
import '../../places/providers/places_providers.dart';
import '../../reminders/providers/commute_providers.dart';
import '../../diary/presentation/diary_screen.dart';
import '../../rewards/presentation/rewards_screen.dart';
import '../../transparency/presentation/privacy_screen.dart';
import '../../trips/providers/tracking_providers.dart';
import '../../trips/providers/trip_providers.dart';
import 'home_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  static const _tabs = <Widget>[
    HomeScreen(),
    DiaryScreen(),
    InsightsScreen(),
    RewardsScreen(),
    PrivacyScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Trips detected while the app was in the background are waiting in the inbox.
    if (state == AppLifecycleState.resumed) {
      ref.read(tripsProvider.notifier).importPending();
      // Restarts the service if it died and re-syncs live status.
      ref.read(trackingProvider.notifier).refreshFromService();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Background work that keeps names and commute alerts current.
    ref.watch(placeGeocoderProvider);
    ref.watch(commuteSyncProvider);
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(key: ValueKey(_index), child: _tabs[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Diary'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Insights'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events_rounded),
              label: 'Rewards'),
          NavigationDestination(
              icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield_rounded), label: 'Privacy'),
        ],
      ),
    );
  }
}
