import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/if_then_rule.dart';
import '../services/if_then_automation_engine.dart';

class IfThenEditorScreen extends StatefulWidget {
  const IfThenEditorScreen({super.key});

  @override
  State<IfThenEditorScreen> createState() => _IfThenEditorScreenState();
}

class _IfThenEditorScreenState extends State<IfThenEditorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IF-THEN Automation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRuleDialog(context),
          ),
        ],
      ),
      body: Consumer<IfThenAutomationEngine>(
        builder: (context, engine, child) {
          return Column(
            children: [
              // Engine status
              Container(
                padding: const EdgeInsets.all(16),
                color: engine.isRunning ? Colors.green.shade100 : Colors.red.shade100,
                child: Row(
                  children: [
                    Icon(
                      engine.isRunning ? Icons.play_arrow : Icons.stop,
                      color: engine.isRunning ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      engine.isRunning ? 'Automation Running' : 'Automation Stopped',
                      style: TextStyle(
                        color: engine.isRunning ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: engine.isRunning,
                      onChanged: (value) {
                        if (value) {
                          engine.start();
                        } else {
                          engine.stop();
                        }
                      },
                    ),
                  ],
                ),
              ),
              // Rules list
              Expanded(
                child: ListView.builder(
                  itemCount: engine.rules.length,
                  itemBuilder: (context, index) {
                    final rule = engine.rules[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Switch(
                              value: rule.enabled,
                              onChanged: (_) => engine.toggleRule(rule.id),
                            ),
                            title: Text(
                              rule.name,
                              style: TextStyle(
                                decoration: rule.enabled ? null : TextDecoration.lineThrough,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rule.getConditionDisplay(),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('THEN: ${rule.getActionDisplay()}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: rule.enabled 
                                    ? () => _testRule(context, rule.id)
                                    : null,
                                  tooltip: 'Test Rule',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEditRuleDialog(context, rule),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteRule(context, rule.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _testRule(BuildContext context, String ruleId) async {
    final engine = context.read<IfThenAutomationEngine>();
    final success = await engine.manualTrigger(ruleId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Rule triggered successfully' : 'Failed to trigger rule'),
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context) {
    _showRuleDialog(context, null);
  }

  void _showEditRuleDialog(BuildContext context, IfThenRule rule) {
    _showRuleDialog(context, rule);
  }

  void _showRuleDialog(BuildContext context, IfThenRule? existingRule) {
    final nameController = TextEditingController(text: existingRule?.name ?? '');
    final thresholdController = TextEditingController(
      text: existingRule?.threshold.toString() ?? '26.0',
    );
    final tempController = TextEditingController(
      text: existingRule?.targetTemp?.toString() ?? '24.0',
    );
    
    SensorType sensor = existingRule?.sensor ?? SensorType.temperature;
    ConditionType condition = existingRule?.condition ?? ConditionType.greaterThan;
    List<AcAction> selectedActions = existingRule?.actions.toList() ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existingRule == null ? 'Add IF-THEN Rule' : 'Edit IF-THEN Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rule name
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Rule Name'),
                ),
                const SizedBox(height: 16),
                
                // IF section
                const Text('IF:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                DropdownButtonFormField<SensorType>(
                  value: sensor,
                  decoration: const InputDecoration(labelText: 'Sensor'),
                  items: SensorType.values.map((s) => 
                    DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()))
                  ).toList(),
                  onChanged: (v) => setState(() => sensor = v!),
                ),
                DropdownButtonFormField<ConditionType>(
                  value: condition,
                  decoration: const InputDecoration(labelText: 'Condition'),
                  items: ConditionType.values.map((c) => 
                    DropdownMenuItem(value: c, child: Text(_conditionDisplay(c)))
                  ).toList(),
                  onChanged: (v) => setState(() => condition = v!),
                ),
                TextField(
                  controller: thresholdController,
                  decoration: const InputDecoration(labelText: 'Threshold'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                // THEN section
                const Text('THEN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Wrap(
                  spacing: 8,
                  children: AcAction.values.map((action) {
                    final isSelected = selectedActions.contains(action);
                    return FilterChip(
                      label: Text(_actionDisplay(action)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedActions.add(action);
                          } else {
                            selectedActions.remove(action);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                
                // Target temp if setTemp is selected
                if (selectedActions.contains(AcAction.setTemp))
                  TextField(
                    controller: tempController,
                    decoration: const InputDecoration(labelText: 'Target Temperature (°C)'),
                    keyboardType: TextInputType.number,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (selectedActions.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select at least one action')),
                  );
                  return;
                }
                
                final engine = context.read<IfThenAutomationEngine>();
                final rule = IfThenRule(
                  id: existingRule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.isEmpty ? 'New Rule' : nameController.text,
                  sensor: sensor,
                  condition: condition,
                  threshold: double.tryParse(thresholdController.text) ?? 26.0,
                  actions: selectedActions,
                  targetTemp: selectedActions.contains(AcAction.setTemp) 
                    ? double.tryParse(tempController.text) 
                    : null,
                );
                
                if (existingRule == null) {
                  engine.addRule(rule);
                } else {
                  engine.updateRule(rule);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _conditionDisplay(ConditionType c) {
    switch (c) {
      case ConditionType.greaterThan: return '> (Greater Than)';
      case ConditionType.lessThan: return '< (Less Than)';
      case ConditionType.equalTo: return '= (Equal To)';
      case ConditionType.greaterThanOrEqual: return '>= (Greater or Equal)';
      case ConditionType.lessThanOrEqual: return '<= (Less or Equal)';
    }
  }

  String _actionDisplay(AcAction a) {
    switch (a) {
      case AcAction.turnOn: return 'Turn ON';
      case AcAction.turnOff: return 'Turn OFF';
      case AcAction.setCoolMode: return 'Cool Mode';
      case AcAction.setHeatMode: return 'Heat Mode';
      case AcAction.setDryMode: return 'Dry Mode';
      case AcAction.setFanMode: return 'Fan Mode';
      case AcAction.setTemp: return 'Set Temp';
      case AcAction.setFanLow: return 'Fan Low';
      case AcAction.setFanMedium: return 'Fan Medium';
      case AcAction.setFanHigh: return 'Fan High';
      case AcAction.setFanAuto: return 'Fan Auto';
    }
  }

  void _deleteRule(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: const Text('Are you sure you want to delete this rule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<IfThenAutomationEngine>().deleteRule(id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
