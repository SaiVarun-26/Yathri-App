import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/fuel_profile.dart';

/// Asks for vehicle type, mileage and fuel price. Used in onboarding and in
/// the "Your vehicle" dialog so both behave the same.
class VehicleForm extends StatefulWidget {
  const VehicleForm({super.key, required this.initial, required this.onChanged, this.showService = false});

  final FuelProfile initial;
  final ValueChanged<FuelProfile> onChanged;

  /// Also ask how often the vehicle is serviced.
  final bool showService;

  @override
  State<VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<VehicleForm> {
  late VehicleType _type = widget.initial.vehicleType;
  late final _car = TextEditingController(text: _fmt(widget.initial.carKmpl));
  late final _bike = TextEditingController(text: _fmt(widget.initial.bikeKmpl));
  late final _price = TextEditingController(text: _fmt(widget.initial.pricePerLitre));
  late final _service = TextEditingController(text: widget.initial.serviceEveryKm.toString());

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void initState() {
    super.initState();
    // Tell the parent the starting values straight away, so "Continue" with
    // no edits still saves what is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final c in [_car, _bike, _price, _service]) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    double read(TextEditingController c, double fallback) {
      final v = double.tryParse(c.text.trim());
      return v == null || v <= 0 ? fallback : v;
    }

    final base = widget.initial;
    widget.onChanged(base.copyWith(
      vehicleType: _type,
      carKmpl: read(_car, base.carKmpl),
      bikeKmpl: read(_bike, base.bikeKmpl),
      pricePerLitre: read(_price, base.pricePerLitre),
      serviceEveryKm: widget.showService
          ? (int.tryParse(_service.text.trim())?.clamp(0, 100000) ?? base.serviceEveryKm)
          : base.serviceEveryKm,
    ));
  }

  Widget _field(TextEditingController c, String label, {String? helper, bool integer = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          onChanged: (_) => _emit(),
          keyboardType: TextInputType.numberWithOptions(decimal: !integer),
          decoration: InputDecoration(labelText: label, helperText: helper),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('What do you drive or ride?', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final v in VehicleType.values)
          ChoiceChip(
            label: Text(v.label),
            selected: v == _type,
            showCheckmark: false,
            selectedColor: AppColors.forest,
            backgroundColor: AppColors.naturalWhite,
            side: const BorderSide(color: AppColors.line),
            labelStyle: TextStyle(color: v == _type ? AppColors.naturalWhite : AppColors.ink),
            onSelected: (_) {
              setState(() => _type = v);
              _emit();
            },
          ),
      ]),
      const SizedBox(height: 18),
      if (_type.hasBike) _field(_bike, 'Bike or scooter mileage (km per litre)'),
      if (_type.hasCar) _field(_car, 'Car mileage (km per litre)'),
      if (_type != VehicleType.none)
        _field(_price, 'Petrol price today (₹ per litre)', helper: 'You can change this any time.'),
      if (widget.showService && _type != VehicleType.none)
        _field(_service, 'Service every (km, 0 for none)', integer: true),
      if (_type == VehicleType.none)
        Text('No problem. Bus, auto and taxi fares are still estimated for you.',
            style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
