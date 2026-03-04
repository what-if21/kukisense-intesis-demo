class SensorReading {
  final double temperature;
  final double humidity;
  final int co2;
  final double pm25;
  final double pm10;
  final double pm1;
  final double pm4;
  final double tvoc;
  final DateTime timestamp;

  SensorReading({
    required this.temperature,
    required this.humidity,
    required this.co2,
    required this.pm25,
    required this.pm10,
    required this.pm1,
    required this.pm4,
    required this.tvoc,
    required this.timestamp,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      humidity: (json['humidity'] ?? 0.0).toDouble(),
      co2: (json['co2'] ?? 0).toInt(),
      pm25: (json['pm25'] ?? 0.0).toDouble(),
      pm10: (json['pm10'] ?? 0.0).toDouble(),
      pm1: (json['pm1'] ?? 0.0).toDouble(),
      pm4: (json['pm4'] ?? 0.0).toDouble(),
      tvoc: (json['tvoc'] ?? 0.0).toDouble(),
      timestamp: DateTime.now(),
    );
  }

  // Parse from ThingsBoard telemetry response
  factory SensorReading.fromThingsBoard(Map<String, dynamic> data) {
    double getValue(String key) {
      if (data.containsKey(key) && data[key] is List && data[key].isNotEmpty) {
        return (data[key][0]['value'] ?? 0.0).toDouble();
      }
      return 0.0;
    }

    int getIntValue(String key) {
      if (data.containsKey(key) && data[key] is List && data[key].isNotEmpty) {
        return (data[key][0]['value'] ?? 0).toInt();
      }
      return 0;
    }

    return SensorReading(
      temperature: getValue('Temp'),           // Temperature
      humidity: getValue('RH'),                // Humidity
      co2: getIntValue('CO2'),                 // CO2
      pm25: getValue('PM25'),                  // PM2.5
      pm10: getValue('PM10'),                  // PM10
      pm1: 0.0,                                // Not available
      pm4: 0.0,                                // Not available
      tvoc: getValue('CH2O'),                  // Formaldehyde (CH2O)
      timestamp: DateTime.now(),
    );
  }

  String getStatus(String sensor) {
    switch (sensor) {
      case 'temperature':
        if (temperature > 30) return 'critical';
        if (temperature > 26) return 'warning';
        return 'good';
      case 'co2':
        if (co2 > 1500) return 'critical';
        if (co2 > 1000) return 'warning';
        return 'good';
      case 'pm25':
        if (pm25 > 55) return 'critical';
        if (pm25 > 35) return 'warning';
        return 'good';
      default:
        return 'good';
    }
  }
}
