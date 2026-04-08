import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nds_save_sync/screens/archive.dart';
import 'package:nds_save_sync/screens/dashboard.dart';

void main() {
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NDS Save Sync',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1e1e2e),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF89b4fa),
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xFF89b4fa),
              surface: const Color(0xFF1e1e2e),
              surfaceContainerLow: const Color(0xFF313244),
              surfaceContainerHigh: const Color(0xFF45475a),
              surfaceContainerHighest: const Color(0xFF585b70),
              error: const Color(0xFFf38ba8),
            ),
      ),
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _controller = PageController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  Widget _dots() {
    final page = _controller.hasClients ? (_controller.page ?? 0) : 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [0, 1].map((i) {
        final opacity = 1.0 - (page - i).abs().clamp(0.0, 0.7);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: opacity),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView(
          controller: _controller,
          children: const [
            _KeepAlive(child: Dashboard()),
            Archive(),
          ],
        ),
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: SafeArea(
            child: _dots(),
          ),
        ),
      ],
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
