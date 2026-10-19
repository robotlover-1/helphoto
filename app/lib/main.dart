import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/capture_screen.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 摄影指导',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const CaptureScreen(),
    );
  }
}
