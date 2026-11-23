import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fuel_profile.dart';

class FuelRepository {
  static const _keys = (
    vehicle: 'fuel_vehicle',
    car: 'fuel_car_kmpl',
    bike: 'fuel_bike_kmpl',
    price: 'fuel_price',
    interval: 'fuel_service_km',
    serviced: 'fuel_last_service_ms',
    configured: 'fuel_configured',
  );

  Future<FuelProfile> load() async {
    final p = await SharedPreferences.getInstance();
    const d = FuelProfile();
    return FuelProfile(
      vehicleType: VehicleType.values.firstWhere(
        (v) => v.name == p.getString(_keys.vehicle),
        orElse: () => d.vehicleType,
      ),
      carKmpl: p.getDouble(_keys.car) ?? d.carKmpl,
      bikeKmpl: p.getDouble(_keys.bike) ?? d.bikeKmpl,
      pricePerLitre: p.getDouble(_keys.price) ?? d.pricePerLitre,
      serviceEveryKm: p.getInt(_keys.interval) ?? d.serviceEveryKm,
      lastServiceMs: p.getInt(_keys.serviced),
      configured: p.getBool(_keys.configured) ?? false,
    );
  }

  Future<void> save(FuelProfile f) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keys.vehicle, f.vehicleType.name);
    await p.setDouble(_keys.car, f.carKmpl);
    await p.setDouble(_keys.bike, f.bikeKmpl);
    await p.setDouble(_keys.price, f.pricePerLitre);
    await p.setInt(_keys.interval, f.serviceEveryKm);
    final serviced = f.lastServiceMs;
    if (serviced != null) await p.setInt(_keys.serviced, serviced);
    await p.setBool(_keys.configured, f.configured);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    for (final k in [_keys.vehicle, _keys.car, _keys.bike, _keys.price, _keys.interval, _keys.serviced, _keys.configured]) {
      await p.remove(k);
    }
  }
}
