import 'package:flutter/material.dart';
import './screens/onboarding.dart';
import './screens/dashboard.dart';

void main() {
  runApp(const App());
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
