import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_reading.dart';
import '../models/automation_rule.dart';
import 'ac_mqtt_service.dart';

class AutomationEngine extends ChangeNotifier {
  Timer? _timer;
  List<AutomationRule> _rules = [];
  final AcMqttService _mqttService;
  SensorReading? _lastReading;

  AutomationEngine({AcMqttService? mqttService}) 
    : _mqttService = mqttService ?? AcMqttService();

  List<AutomationRule> get rules => _rules;

  Future<void> initialize() async {
    await loadRules();
    if (_rules.isEmpty) {
      _rules = getDefaultRules();
      await saveRules();
    }
    start();
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _evaluateRules());
  }

  void updateSensorData(SensorReading reading) {
    _lastReading = reading;
  }

  void _evaluateRules() {
    if (_lastReading == null) return;
    for (var rule in _rules.where((r) => r.enabled)) {
      if (_shouldTrigger(rule)) {
        _executeAction(rule.action);
      }
    }
  }

  bool _shouldTrigger(AutomationRule rule) {
    double? value;
    switch (rule.sensor) {
      case 'temperature': value = _lastReading!.temperature; break;
      case 'co2': value = _lastReading!.co2.toDouble(); break;
      case 'pm25': value = _lastReading!.pm25; break;
      default: return false;
    }
    switch (rule.operator) {
      case '>': return value > rule.threshold;
      case '<': return value < rule.threshold;
      default: return false;
    }
  }

  void _executeAction(Map<String, dynamic> action) {
    _mqttService.sendAcCommand(action);
  }

  Future<void> loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = prefs.getStringList('automation_rules') ?? [];
    _rules = rulesJson.map((json) => AutomationRule.fromJson(jsonDecode(json))).toList();
    notifyListeners();
  }

  Future<void> saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = _rules.map((rule) => jsonEncode(rule.toJson())).toList();
    await prefs.setStringList('automation_rules', rulesJson);
    notifyListeners();
  }

  void toggleRule(String id) {
    final rule = _rules.firstWhere((r) => r.id == id);
    rule.enabled = !rule.enabled;
    saveRules();
  }

  void addRule(AutomationRule rule) {
    _rules.add(rule);
    saveRules();
  }

  void updateRule(AutomationRule rule) {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _rules[index] = rule;
      saveRules();
    }
  }

  void deleteRule(String id) {
    _rules.removeWhere((r) => r.id == id);
    saveRules();
  }
}
