class AutomationRule {
  String id;
  String name;
  bool enabled;
  String sensor;
  String operator;
  double threshold;
  Map<String, dynamic> action;

  AutomationRule({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.sensor,
    required this.operator,
    required this.threshold,
    required this.action,
  });

  factory AutomationRule.fromJson(Map<String, dynamic> json) {
    return AutomationRule(
      id: json['id'],
      name: json['name'],
      enabled: json['enabled'] ?? true,
      sensor: json['sensor'],
      operator: json['operator'],
      threshold: json['threshold'].toDouble(),
      action: json['action'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'sensor': sensor,
      'operator': operator,
      'threshold': threshold,
      'action': action,
    };
  }
}

List<AutomationRule> getDefaultRules() {
  return [
    AutomationRule(
      id: 'rule_temp',
      name: 'Hot Day Cooling',
      sensor: 'temperature',
      operator: '>',
      threshold: 26.0,
      action: {'power': true, 'mode': 'COOL', 'temp': 24.0, 'fan': 'AUTO'},
    ),
    AutomationRule(
      id: 'rule_co2',
      name: 'High CO2 Ventilation',
      sensor: 'co2',
      operator: '>',
      threshold: 1000.0,
      action: {'power': true, 'mode': 'FAN', 'fan': 'HIGH'},
    ),
    AutomationRule(
      id: 'rule_pm25',
      name: 'Air Quality Filter',
      sensor: 'pm25',
      operator: '>',
      threshold: 35.0,
      action: {'power': true, 'mode': 'COOL', 'temp': 24.0, 'fan': 'AUTO'},
    ),
  ];
}
