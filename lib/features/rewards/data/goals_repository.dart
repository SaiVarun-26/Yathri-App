import 'package:shared_preferences/shared_preferences.dart';

import '../domain/goals.dart';

class GoalsRepository {
  static const _walk = 'goal_walk_km_week';
  static const _cycle = 'goal_cycle_km_week';
  static const _fuel = 'goal_fuel_budget_month';
  static const _eco = 'goal_eco_score';

  Future<TravelGoals> load() async {
    final p = await SharedPreferences.getInstance();
    const d = TravelGoals();
    return TravelGoals(
      walkKmPerWeek: p.getDouble(_walk) ?? d.walkKmPerWeek,
      cycleKmPerWeek: p.getDouble(_cycle) ?? d.cycleKmPerWeek,
      fuelBudgetPerMonth: p.getDouble(_fuel) ?? d.fuelBudgetPerMonth,
      ecoScoreTarget: p.getInt(_eco) ?? d.ecoScoreTarget,
    );
  }

  Future<void> save(TravelGoals g) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_walk, g.walkKmPerWeek);
    await p.setDouble(_cycle, g.cycleKmPerWeek);
    await p.setDouble(_fuel, g.fuelBudgetPerMonth);
    await p.setInt(_eco, g.ecoScoreTarget);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    for (final k in [_walk, _cycle, _fuel, _eco]) {
      await p.remove(k);
    }
  }
}
