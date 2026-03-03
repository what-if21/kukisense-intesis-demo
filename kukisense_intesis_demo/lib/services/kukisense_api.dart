import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_reading.dart';

class KukisenseApi {
  static const String baseUrl = 'https://dashboard.what-if.sg';
  static const String deviceId = 'acd184f0-dc97-11f0-9bc1-e37c1229cd44';
  static const String username = 'demo';
  static const String password = 'demo123';

  String get basicAuth {
    return 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  }

  Future<SensorReading?> fetchSensorData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/sensors/$deviceId/data'),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SensorReading.fromJson(data);
      } else {
        print('API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('API Exception: $e');
      return null;
    }
  }
}
