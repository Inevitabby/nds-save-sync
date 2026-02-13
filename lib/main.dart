import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/screens/onboarding.dart';
import 'package:nds_save_sync/screens/dashboard.dart';

void main() {
  runApp(
    const ProviderScope(
      child: App()
    )
  );
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Flutter Demo",
      theme: ThemeData.dark(),
      home: Dashboard(),
    );
  }
}
