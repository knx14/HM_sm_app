class ManualResultParameterDef {
  const ManualResultParameterDef({
    required this.name,
    required this.unitLabel,
  });

  final String name;
  final String? unitLabel;

  String get label {
    if (unitLabel == null || unitLabel!.isEmpty) {
      return name;
    }
    return '$name [$unitLabel]';
  }
}

const manualResultParameters = <ManualResultParameterDef>[
  ManualResultParameterDef(name: 'B', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'CaO', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'CEC', unitLabel: 'meq/100g'),
  ManualResultParameterDef(name: 'Cu', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'Fe', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'FU', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'K2O', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'MgO', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'Mn', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'NH4-N', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'NO3-N', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'P2O5', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'PA', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'SiO2', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: 'Zn', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: '易還元性マンガン', unitLabel: 'mg/100g'),
  ManualResultParameterDef(name: '遊離酸化鉄', unitLabel: 'mg/100g'),
];
