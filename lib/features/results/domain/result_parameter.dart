enum ResultParameter {
  cec('CEC', 'meq/100g'),
  k2o('K2O', 'mg/100g'),
  cao('CaO', 'mg/100g'),
  mgo('MgO', 'mg/100g');

  final String apiName;
  final String unit;
  const ResultParameter(this.apiName, this.unit);
}

String unitForParameter(String parameterName, [String? stored]) {
  if (stored != null && stored.isNotEmpty) {
    return stored;
  }
  for (final parameter in ResultParameter.values) {
    if (parameter.apiName == parameterName) {
      return parameter.unit;
    }
  }
  return parameterName == 'CEC' ? 'meq/100g' : 'mg/100g';
}

