import 'dart:convert';

enum ConditionType {
  greaterThan,
  lessThan,
  equalTo,
  greaterThanOrEqual,
  lessThanOrEqual,
}

enum SensorType {
  temperature,
  humidity,
  co2,
  pm25,
  pm10,
  pm1,
  pm4,
  tvoc,
}

enum AcAction {
  turnOn,
  turnOff,
  setCoolMode,
  setHeatMode,
  setDryMode,
  setFanMode,
  setTemp,
  setFanLow,
  setFanMedium,
  setFanHigh,
  setFanAuto,
}

class IfThenRule {
  String id;
  String name;
  bool enabled;
  
  // IF condition
  SensorType sensor;
  ConditionType condition;
  double threshold;
  
  // THEN action
  List<AcAction> actions;
  double? targetTemp; // For setTemp action
  
  IfThenRule({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.sensor,
    required this.condition,
    required this.threshold,
    required this.actions,
    this.targetTemp,
  });
  
  factory IfThenRule.fromJson(Map<String, dynamic> json) {
    return IfThenRule(
      id: json['id'],
      name: json['name'],
      enabled: json['enabled'] ?? true,
      sensor: SensorType.values.byName(json['sensor']),
      condition: ConditionType.values.byName(json['condition']),
      threshold: json['threshold'].toDouble(),
      actions: (json['actions'] as List).map((a) => AcAction.values.byName(a)).toList(),
      targetTemp: json['targetTemp']?.toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'sensor': sensor.name,
      'condition': condition.name,
      'threshold': threshold,
      'actions': actions.map((a) => a.name).toList(),
      'targetTemp': targetTemp,
    };
  }
  
  String getConditionDisplay() {
    final sensorStr = sensor.name.toUpperCase();
    final condStr = {
      ConditionType.greaterThan: '>',
      ConditionType.lessThan: '<',
      ConditionType.equalTo: '=',
      ConditionType.greaterThanOrEqual: '>=',
      ConditionType.lessThanOrEqual: '<=',
    }[condition];
    return 'IF $sensorStr $condStr $threshold';
  }
  
  String getActionDisplay() {
    return actions.map((a) {
      switch (a) {
        case AcAction.turnOn: return 'Turn ON';
        case AcAction.turnOff: return 'Turn OFF';
        case AcAction.setCoolMode: return 'COOL mode';
        case AcAction.setHeatMode: return 'HEAT mode';
        case AcAction.setDryMode: return 'DRY mode';
        case AcAction.setFanMode: return 'FAN mode';
        case AcAction.setTemp: return 'Set temp ${targetTemp}°C';
        case AcAction.setFanLow: return 'Fan LOW';
        case AcAction.setFanMedium: return 'Fan MEDIUM';
        case AcAction.setFanHigh: return 'Fan HIGH';
        case AcAction.setFanAuto: return 'Fan AUTO';
      }
    }).join(', ');
  }
  
  // Convert actions to RPC params
  Map<String, dynamic> toRpcParams() {
    final params = <String, dynamic>{};
    
    for (final action in actions) {
      switch (action) {
        case AcAction.turnOn:
          params['power'] = true;
          break;
        case AcAction.turnOff:
          params['power'] = false;
          break;
        case AcAction.setCoolMode:
          params['mode'] = 'COOL';
          break;
        case AcAction.setHeatMode:
          params['mode'] = 'HEAT';
          break;
        case AcAction.setDryMode:
          params['mode'] = 'DRY';
          break;
        case AcAction.setFanMode:
          params['mode'] = 'FAN';
          break;
        case AcAction.setTemp:
          if (targetTemp != null) {
            params['temp'] = targetTemp;
          }
          break;
        case AcAction.setFanLow:
          params['fan'] = 'LOW';
          break;
        case AcAction.setFanMedium:
          params['fan'] = 'MEDIUM';
          break;
        case AcAction.setFanHigh:
          params['fan'] = 'HIGH';
          break;
        case AcAction.setFanAuto:
          params['fan'] = 'AUTO';
          break;
      }
    }
    
    return params;
  }
}

// Default IF-THEN rules
List<IfThenRule> getDefaultIfThenRules() {
  return [
    IfThenRule(
      id: '1',
      name: 'Hot Day - Cool Down',
      sensor: SensorType.temperature,
      condition: ConditionType.greaterThan,
      threshold: 26.0,
      actions: [AcAction.turnOn, AcAction.setCoolMode, AcAction.setTemp, AcAction.setFanAuto],
      targetTemp: 24.0,
    ),
    IfThenRule(
      id: '2',
      name: 'High CO2 - Ventilate',
      sensor: SensorType.co2,
      condition: ConditionType.greaterThan,
      threshold: 1000.0,
      actions: [AcAction.turnOn, AcAction.setFanMode, AcAction.setFanHigh],
    ),
    IfThenRule(
      id: '3',
      name: 'Poor Air Quality - Filter',
      sensor: SensorType.pm25,
      condition: ConditionType.greaterThan,
      threshold: 35.0,
      actions: [AcAction.turnOn, AcAction.setCoolMode, AcAction.setFanAuto],
    ),
    IfThenRule(
      id: '4',
      name: 'Comfortable Temp - Turn Off',
      sensor: SensorType.temperature,
      condition: ConditionType.lessThanOrEqual,
      threshold: 24.0,
      actions: [AcAction.turnOff],
    ),
  ];
}
