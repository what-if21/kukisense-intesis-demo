import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_reading.dart';

class ThingsBoardApi {
  static const String baseUrl = 'https://dashboard.what-if.sg';
  static const String username = 'demo';
  static const String password = 'demo123';
  
  // Device IDs
  static const String iaqDeviceId = 'acd184f0-dc97-11f0-9bc1-e37c1229cd44'; // Kukisense IAQ sensor
  static const String acDeviceId = 'your-ac-device-id'; // AC control device (hazelnut)
  
  String? _token;
  
  Future<bool> login() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }
  
  // Get IAQ sensor telemetry
  Future<SensorReading?> getIaqTelemetry() async {
    if (_token == null) await login();
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/plugins/telemetry/DEVICE/$iaqDeviceId/values/timeseries?keys=temperature,humidity,co2,pm25,pm10,pm1,pm4,tvoc'),
        headers: {
          'X-Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SensorReading.fromThingsBoard(data);
      }
      return null;
    } catch (e) {
      print('Telemetry error: $e');
      return null;
    }
  }
  
  // Send RPC to AC device
  Future<bool> sendAcCommand(Map<String, dynamic> params) async {
    if (_token == null) await login();
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/plugins/rpc/twoway/$acDeviceId'),
        headers: {
          'X-Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'method': 'acControl',
          'params': params,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('RPC error: $e');
      return false;
    }
  }
  
  // Get AC device status
  Future<Map<String, dynamic>?> getAcStatus() async {
    if (_token == null) await login();
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/plugins/telemetry/DEVICE/$acDeviceId/values/timeseries?keys=ac_power,ac_mode,ac_setpoint,ac_fan,ac_online'),
        headers: {
          'X-Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('AC status error: $e');
      return null;
    }
  }
}
