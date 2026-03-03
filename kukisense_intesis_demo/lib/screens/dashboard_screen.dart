import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sensor_reading.dart';
import '../services/kukisense_api.dart';
import '../services/automation_engine.dart';
import 'automation_screen.dart';

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
      context.read<AutomationEngine>().initialize();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final api = context.read<KukisenseApi>();
    final reading = await api.fetchSensorData();
    if (mounted) {
      setState(() { _reading = reading; _isLoading = false; });
      if (reading != null) {
        context.read<AutomationEngine>().updateSensorData(reading);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kukisense Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_mode),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AutomationScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
        : _reading == null ? const Center(child: Text('Failed to load sensor data'))
        : RefreshIndicator(
            onRefresh: _fetchData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSensorCard('Temperature', '${_reading!.temperature.toStringAsFixed(1)}°C', _reading!.getStatus('temperature')),
                _buildSensorCard('CO2', '${_reading!.co2} ppm', _reading!.getStatus('co2')),
                _buildSensorCard('PM2.5', '${_reading!.pm25.toStringAsFixed(1)} µg/m³', _reading!.getStatus('pm25')),
              ],
            ),
          ),
    );
  }

  Widget _buildSensorCard(String label, String value, String status) {
    Color color = status == 'good' ? Colors.green : status == 'warning' ? Colors.orange : Colors.red;
    return Card(
      child: ListTile(
        leading: Icon(Icons.sensors, color: color),
        title: Text(label),
        subtitle: Text(value),
        trailing: Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ),
    );
  }
}
