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
  ManualResultParameterDef(name: 'B', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: 'CaO', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: 'CEC', unitLabel: 'cmol/kg'),
  ManualResultParameterDef(name: 'Cu', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: 'Fe', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: 'FU', unitLabel: null),
  ManualResultParameterDef(name: 'K2O', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: 'MgO', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: 'Mn', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: 'NH4-N', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: 'NO3-N', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: 'P2O5', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: 'PA', unitLabel: null),
  ManualResultParameterDef(name: 'SiO2', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: 'Zn', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: '易還元性マンガン', unitLabel: 'mg/kg'),
  ManualResultParameterDef(name: '遊離酸化鉄', unitLabel: 'mg/kg'),
];
