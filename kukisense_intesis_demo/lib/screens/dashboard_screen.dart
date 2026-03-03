import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sensor_reading.dart';
import '../services/thingsboard_api.dart';
import '../services/if_then_automation_engine.dart';
import 'if_then_editor_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SensorReading? _reading;
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchData());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IfThenAutomationEngine>().initialize();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final api = context.read<ThingsBoardApi>();
    final reading = await api.getIaqTelemetry();
    if (mounted) {
      setState(() { _reading = reading; _isLoading = false; });
      if (reading != null) {
        context.read<IfThenAutomationEngine>().updateSensorData(reading);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kukisense IAQ + AC Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rule_folder),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IfThenEditorScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _reading == null 
          ? const Center(child: Text('Failed to load sensor data'))
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // IAQ Sensor Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'IAQ Sensor (Kukisense)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          _buildSensorRow('Temperature', '${_reading!.temperature.toStringAsFixed(1)}°C', _reading!.getStatus('temperature')),
                          _buildSensorRow('Humidity', '${_reading!.humidity.toStringAsFixed(1)}%', 'good'),
                          _buildSensorRow('CO2', '${_reading!.co2} ppm', _reading!.getStatus('co2')),
                          _buildSensorRow('PM2.5', '${_reading!.pm25.toStringAsFixed(1)} µg/m³', _reading!.getStatus('pm25')),
                          _buildSensorRow('PM10', '${_reading!.pm10.toStringAsFixed(1)} µg/m³', 'good'),
                          _buildSensorRow('TVOC', '${_reading!.tvoc.toStringAsFixed(1)} ppb', 'good'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // IF-THEN Status
                  Consumer<IfThenAutomationEngine>(
                    builder: (context, engine, child) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'IF-THEN Automation',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: engine.isRunning ? Colors.green : Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      engine.isRunning ? 'RUNNING' : 'STOPPED',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Text('Active Rules: ${engine.rules.where((r) => r.enabled).length}/${engine.rules.length}'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const IfThenEditorScreen()),
                                ),
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit IF-THEN Rules'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSensorRow(String label, String value, String status) {
    Color color = status == 'good' ? Colors.green : status == 'warning' ? Colors.orange : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
