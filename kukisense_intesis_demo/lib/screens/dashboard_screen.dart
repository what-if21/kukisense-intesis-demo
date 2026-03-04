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
  Map<String, dynamic>? _acStatus;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timer;

  // AC Control state
  bool _acPower = false;
  String _acMode = 'COOL';
  double _acSetpoint = 24;
  String _acFan = '5';
  bool _isSendingCommand = false;

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
    try {
      final api = context.read<ThingsBoardApi>();
      final reading = await api.getIaqTelemetry();
      final acStatus = await api.getAcStatus();
      
      if (mounted) {
        setState(() {
          _reading = reading;
          _acStatus = acStatus;
          _isLoading = false;
          _errorMessage = null;
          
          // Update AC state from telemetry
          if (acStatus != null) {
            _updateAcStateFromTelemetry(acStatus);
          }
        });
        if (reading != null) {
          context.read<IfThenAutomationEngine>().updateSensorData(reading);
        }
      }
    } catch (e, stackTrace) {
      print('Error fetching data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  dynamic _getAcValue(Map<String, dynamic> status, String key) {
    if (status.containsKey(key) && status[key] is List && status[key].isNotEmpty) {
      return status[key][0]['value'];
    }
    return null;
  }
  
  // Parse AC status with proper type conversion
  void _updateAcStateFromTelemetry(Map<String, dynamic> acStatus) {
    // Parse power - stored as string "true" or "false"
    final powerValue = _getAcValue(acStatus, 'ac_power');
    if (powerValue != null) {
      _acPower = powerValue.toString().toLowerCase() == 'true';
    }
    
    // Parse mode - stored as string
    final modeValue = _getAcValue(acStatus, 'ac_mode');
    if (modeValue != null) {
      _acMode = modeValue.toString().toLowerCase();
    }
    
    // Parse setpoint - stored with factor of 10 (e.g., 180 = 18.0°C)
    final setpointValue = _getAcValue(acStatus, 'ac_setpoint');
    if (setpointValue != null) {
      final rawSetpoint = double.tryParse(setpointValue.toString()) ?? 24.0;
      _acSetpoint = rawSetpoint / 10.0; // Divide by 10
    }
    
    // Parse fan - can be "AUTO" or "1"-"5"
    final fanValue = _getAcValue(acStatus, 'ac_fan');
    if (fanValue != null) {
      final fanStr = fanValue.toString().toUpperCase();
      // Handle both "AUTO" and numeric values "1"-"5"
      if (fanStr == 'AUTO' || fanStr == 'AUTO') {
        _acFan = 'AUTO';
      } else {
        // For numeric values, just use as-is (1-5)
        _acFan = fanStr;
      }
    }
    
    print('AC State updated: power=$_acPower, mode=$_acMode, setpoint=$_acSetpoint, fan=$_acFan');
  }

  Future<void> _sendAcCommand() async {
    setState(() => _isSendingCommand = true);
    
    final api = context.read<ThingsBoardApi>();
    
    // Build params
    final params = <String, dynamic>{
      'power': _acPower,
      'mode': _acMode.toUpperCase(),
    };
    
    // Handle setpoint (multiply by 10)
    params['setpoint'] = (_acSetpoint * 10).toInt();
    
    // Handle fan - can be AUTO or 1-5
    if (_acFan == 'AUTO') {
      params['fan'] = 'AUTO';
    } else {
      // For numeric fan speeds 1-5
      params['fan'] = _acFan;
    }
    
    print('Sending AC command: $params');
    final success = await api.sendAcCommand(params);
    
    setState(() => _isSendingCommand = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'AC command sent successfully' : 'Failed to send AC command'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Failed to load sensor data'),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Error: $_errorMessage',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
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
                          _buildSensorRow('TVOC (Formaldehyde)', '${_reading!.tvoc.toStringAsFixed(1)} µg/m³', 'good'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // AC Control Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'AC Control (Manual)',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Switch(
                                value: _acPower,
                                onChanged: (value) {
                                  setState(() => _acPower = value);
                                  _sendAcCommand();
                                },
                              ),
                            ],
                          ),
                          Text(
                            _acPower ? 'AC is ON' : 'AC is OFF',
                            style: TextStyle(
                              color: _acPower ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          
                          // Mode Selection
                          const Text('Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildModeButton('COOL', 'Cool'),
                              _buildModeButton('HEAT', 'Heat'),
                              _buildModeButton('DRY', 'Dry'),
                              _buildModeButton('FAN', 'Fan'),
                              _buildModeButton('AUTO', 'Auto'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Temperature Setpoint
                          Row(
                            children: [
                              const Text('Setpoint:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.remove_circle),
                                onPressed: _acSetpoint > 16
                                  ? () {
                                      setState(() => _acSetpoint--);
                                      _sendAcCommand();
                                    }
                                  : null,
                              ),
                              Text('${_acSetpoint.toInt()}°C', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle),
                                onPressed: _acSetpoint < 30
                                  ? () {
                                      setState(() => _acSetpoint++);
                                      _sendAcCommand();
                                    }
                                  : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Fan Speed
                          const Text('Fan Speed:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildFanButton('1', '1'),
                              _buildFanButton('2', '2'),
                              _buildFanButton('3', '3'),
                              _buildFanButton('4', '4'),
                              _buildFanButton('5', '5'),
                              _buildFanButton('AUTO', 'AUTO'),
                            ],
                          ),
                          
                          if (_isSendingCommand)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
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

  Widget _buildModeButton(String mode, String label) {
    final isSelected = _acMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: _acPower
        ? (selected) {
            if (selected) {
              setState(() => _acMode = mode);
              _sendAcCommand();
            }
          }
        : null,
    );
  }

  Widget _buildFanButton(String fan, String label) {
    final isSelected = _acFan == fan;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: _acPower
        ? (selected) {
            if (selected) {
              setState(() => _acFan = fan);
              _sendAcCommand();
            }
          }
        : null,
    );
  }
}
