import 'package:flutter/material.dart';

import '../domain/insights_engine.dart';

IconData insightIcon(InsightKind kind) => switch (kind) {
      InsightKind.behaviour => Icons.insights_rounded,
      InsightKind.commute => Icons.alt_route_rounded,
      InsightKind.carbon => Icons.eco_rounded,
      InsightKind.money => Icons.savings_rounded,
      InsightKind.trend => Icons.trending_up_rounded,
      InsightKind.timing => Icons.schedule_rounded,
      InsightKind.traffic => Icons.traffic_rounded,
      InsightKind.place => Icons.place_rounded,
    };
