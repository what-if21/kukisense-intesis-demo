import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'services/kukisense_api.dart';
import 'services/ac_mqtt_service.dart';
import 'services/automation_engine.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => KukisenseApi()),
        Provider(create: (_) => AcMqttService()),
        ChangeNotifierProvider(create: (_) => AutomationEngine()),
      ],
      child: MaterialApp(
        title: 'Kukisense AC Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
