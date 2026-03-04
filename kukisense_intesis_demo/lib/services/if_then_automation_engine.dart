import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_reading.dart';
import '../models/if_then_rule.dart';
import 'thingsboard_api.dart';

class IfThenAutomationEngine extends ChangeNotifier {
  Timer? _timer;
  List<IfThenRule> _rules = [];
  final ThingsBoardApi _api;
  SensorReading? _lastReading;
  bool _isRunning = false;
  
  // Track which rules fired to prevent spam
  final Map<String, bool> _ruleFiredState = {};

  IfThenAutomationEngine({ThingsBoardApi? api}) 
    : _api = api ?? ThingsBoardApi();

  List<IfThenRule> get rules => _rules;
  bool get isRunning => _isRunning;

  Future<void> initialize() async {
    await loadRules();
    if (_rules.isEmpty) {
      _rules = getDefaultIfThenRules();
      await saveRules();
    }
    // Note: Login should be done from LoginScreen before calling initialize
    start();
  }

  void start() {
    _timer?.cancel();
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _evaluateRules());
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  // Public method to update sensor data from external source
  void updateSensorData(SensorReading reading) {
    _lastReading = reading;
  }

  Future<void> _evaluateRules() async {
    // Fetch latest sensor data from ThingsBoard
    final reading = await _api.getIaqTelemetry();
    if (reading == null) return;
    
    _lastReading = reading;
    
    for (var rule in _rules.where((r) => r.enabled)) {
      final shouldFire = _shouldTrigger(rule);
      final previouslyFired = _ruleFiredState[rule.id] ?? false;
      
      if (shouldFire && !previouslyFired) {
        // Rule condition met and hasn't fired yet
        await _executeAction(rule);
        _ruleFiredState[rule.id] = true;
      } else if (!shouldFire && previouslyFired) {
        // Rule condition no longer met, reset state
        _ruleFiredState[rule.id] = false;
      }
    }
    
    notifyListeners();
  }

  bool _shouldTrigger(IfThenRule rule) {
    if (_lastReading == null) return false;
    
    double? value;
    switch (rule.sensor) {
      case SensorType.temperature:
        value = _lastReading!.temperature;
        break;
      case SensorType.humidity:
        value = _lastReading!.humidity;
        break;
      case SensorType.co2:
        value = _lastReading!.co2.toDouble();
        break;
      case SensorType.pm25:
        value = _lastReading!.pm25;
        break;
      case SensorType.pm10:
        value = _lastReading!.pm10;
        break;
      case SensorType.pm1:
        value = _lastReading!.pm1;
        break;
      case SensorType.pm4:
        value = _lastReading!.pm4;
        break;
      case SensorType.tvoc:
        value = _lastReading!.tvoc;
        break;
    }
    
    if (value == null) return false;
    
    switch (rule.condition) {
      case ConditionType.greaterThan:
        return value > rule.threshold;
      case ConditionType.lessThan:
        return value < rule.threshold;
      case ConditionType.equalTo:
        return value == rule.threshold;
      case ConditionType.greaterThanOrEqual:
        return value >= rule.threshold;
      case ConditionType.lessThanOrEqual:
        return value <= rule.threshold;
    }
  }

  Future<void> _executeAction(IfThenRule rule) async {
    final params = rule.toRpcParams();
    if (params.isNotEmpty) {
      print('Executing IF-THEN rule: ${rule.name}');
      print('Actions: ${rule.getActionDisplay()}');
      print('RPC params: $params');
      
      final success = await _api.sendAcCommand(params);
      if (success) {
        print('AC command sent successfully');
      } else {
        print('Failed to send AC command');
      }
    }
  }

  // Manual trigger for testing
  Future<bool> manualTrigger(String ruleId) async {
    final rule = _rules.firstWhere((r) => r.id == ruleId);
    if (rule.enabled) {
      await _executeAction(rule);
      return true;
    }
    return false;
  }

  Future<void> loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = prefs.getStringList('if_then_rules') ?? [];
    _rules = rulesJson.map((json) => IfThenRule.fromJson(jsonDecode(json))).toList();
    notifyListeners();
  }

  Future<void> saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = _rules.map((rule) => jsonEncode(rule.toJson())).toList();
    await prefs.setStringList('if_then_rules', rulesJson);
    notifyListeners();
  }

  void addRule(IfThenRule rule) {
    _rules.add(rule);
    _ruleFiredState[rule.id] = false;
    saveRules();
  }

  void updateRule(IfThenRule rule) {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _rules[index] = rule;
      _ruleFiredState[rule.id] = false; // Reset state
      saveRules();
    }
  }

  void toggleRule(String id) {
    final rule = _rules.firstWhere((r) => r.id == id);
    rule.enabled = !rule.enabled;
    if (!rule.enabled) {
      _ruleFiredState[id] = false; // Reset when disabled
    }
    saveRules();
  }

  void deleteRule(String id) {
    _rules.removeWhere((r) => r.id == id);
    _ruleFiredState.remove(id);
    saveRules();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
