import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/automation_rule.dart';
import '../services/automation_engine.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automation Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRuleDialog(context),
          ),
        ],
      ),
      body: Consumer<AutomationEngine>(
        builder: (context, engine, child) {
          return ListView.builder(
            itemCount: engine.rules.length,
            itemBuilder: (context, index) {
              final rule = engine.rules[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: Switch(
                    value: rule.enabled,
                    onChanged: (_) => engine.toggleRule(rule.id),
                  ),
                  title: Text(rule.name),
                  subtitle: Text('IF ${rule.sensor} ${rule.operator} ${rule.threshold}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
              );
            },
          );
        },
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context) {
    _showRuleDialog(context, null);
  }

  void _showEditRuleDialog(BuildContext context, AutomationRule rule) {
    _showRuleDialog(context, rule);
  }

  void _showRuleDialog(BuildContext context, AutomationRule? existingRule) {
    final nameController = TextEditingController(text: existingRule?.name ?? '');
    final thresholdController = TextEditingController(
      text: existingRule?.threshold.toString() ?? '26.0',
    );
    String sensor = existingRule?.sensor ?? 'temperature';
    String operator = existingRule?.operator ?? '>';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingRule == null ? 'Add Rule' : 'Edit Rule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Rule Name'),
              ),
              DropdownButtonFormField<String>(
                value: sensor,
                decoration: const InputDecoration(labelText: 'Sensor'),
                items: ['temperature', 'co2', 'pm25', 'humidity'].map((s) => 
                  DropdownMenuItem(value: s, child: Text(s))
                ).toList(),
                onChanged: (v) => sensor = v!,
              ),
              DropdownButtonFormField<String>(
                value: operator,
                decoration: const InputDecoration(labelText: 'Operator'),
                items: ['>', '<', '>=', '<='].map((op) => 
                  DropdownMenuItem(value: op, child: Text(op))
                ).toList(),
                onChanged: (v) => operator = v!,
              ),
              TextField(
                controller: thresholdController,
                decoration: const InputDecoration(labelText: 'Threshold'),
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
              final engine = context.read<AutomationEngine>();
              final rule = AutomationRule(
                id: existingRule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text,
                sensor: sensor,
                operator: operator,
                threshold: double.tryParse(thresholdController.text) ?? 26.0,
                action: {'power': true, 'mode': 'COOL', 'temp': 24.0},
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
    );
  }

  void _deleteRule(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AutomationEngine>().deleteRule(id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
