import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

enum ConsoleType { unknown, legacy, modern }

class _OnboardingState extends State<Onboarding> {
  final _introKey = GlobalKey<IntroductionScreenState>();
  ConsoleType _selectedConsole = ConsoleType.unknown;

  Future<void> _launchHelpUrl() async {
    final url = Uri.parse(
      'https://github.com/inevitabby/nds-save-sync/wiki/',
    );
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IntroductionScreen(
      key: _introKey,
      allowImplicitScrolling: true,

      next: const Icon(Icons.arrow_forward),
      back: const Icon(Icons.arrow_back),
      showBackButton: true,
      done: const Text('Finish', style: TextStyle(fontWeight: FontWeight.bold)),
      onDone: () {
        // TODO: Navigate to Dashboard
      },

      pages: [
        // PAGE 1: Hardware Selector
        // TODOAdvance to the next slide after clicking a button.
        _screen(
          title: 'Select Console',
          subtitle: 'Connection methods vary by generation.',
          // image: Icon(Icons.devices_other, size: 80, color: colorScheme.primary),
          children: [
            _selectionCard(
              title: 'Legacy Dual-Screen',
              subtitle: 'Gen 4 (NDS/i/Lite)',
              type: ConsoleType.legacy,
            ),
            const SizedBox(height: 8),
            _selectionCard(
              title: 'Modern Dual-Screen',
              subtitle: 'Gen 5 (3D/2D)',
              type: ConsoleType.modern,
            ),
          ],
        ),

        // PAGE 2: Network Instructions
        if (_selectedConsole == ConsoleType.legacy)
          _screen(
            title: 'Legacy Setup',
            subtitle: 'Set up a Hotspot ',
            // icon: Icon(Icons.wifi_lock, size: 80, color: colorScheme.error),
            children: [
              const Text('Set Hotspot Settings:'),
              const Divider(),
              _step(1, 'Open Android Hotspot Settings'),
              _step(2, 'Set Band to "2.4 GHz"'),
              _step(3, 'Set Security to "None/Open"'),
              const Spacer(),
              Text(
                'Gen 4 consoles cannot see WPA2 Wi-Fi\n\n(Remember to disable after use)',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          )
        else if (_selectedConsole == ConsoleType.modern)
          _screen(
            title: 'Modern Setup',
            subtitle:
                'Ensure phone and console are on the same Wi-Fi network.',
            // icon: Icon(Icons.wifi, size: 80, color: colorScheme.primary),
            children: [
              Text(
                "Note: 5GHz is not supported by the console\n\n(If you don't have 2GHz, do Legacy Setup)", // TODOa button for this that easily takes you back?
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          )
        else
          _screen(
            // TODODon't let the user scroll here unless they've selected an option
            title: 'Select System',
            subtitle: 'Please go back and select a system type.',
          ),

        // PAGE 3: Checklist
        _screen(
          title: 'Ready to Connect?',
          subtitle: 'Please check the following!',
          // image: Icon(Icons.check_circle_outline, size: 80, color: colorScheme.primary),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _checkItem('FTP Server running on console'),
                    _checkItem('Console displays IP address'),
                    _checkItem('Console screen is ON'),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: _launchHelpUrl,
              child: const Text('Help / Guide'),
            ),
          ],
        ),
      ],
    );
  }

  PageViewModel _screen({
    required String title,
    required String subtitle,
    Icon? icon,
    List<Widget>? children,
  }) {
    return PageViewModel(
      title: title,
      body: subtitle,
      image: icon,
      decoration: const PageDecoration(bodyAlignment: Alignment.center),
      footer: children != null ? Column(children: children) : null,
    );
  }

  // TODOMake below helpers stateless widgets? (measure performance)
  Widget _selectionCard({
    required String title,
    required String subtitle,
    required ConsoleType type,
  }) {
    final isSelected = _selectedConsole == type;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: isSelected
          ? RoundedRectangleBorder(
              side: BorderSide(color: colorScheme.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        selected: isSelected,
        trailing: isSelected ? const Icon(Icons.check) : null,
        onTap: () => setState(() => _selectedConsole = type),
      ),
    );
  }

  Widget _step(int number, String text) {
    return ListTile(
      leading: CircleAvatar(
        radius: 12,
        child: Text(number.toString(), style: const TextStyle(fontSize: 12)),
      ),
      title: Text(text),
      dense: true,
    );
  }

  // TODOReconsider design (potentially misleading as a clickable or self-updating checklist)
  Widget _checkItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Opacity(opacity: 0.5, child: Icon(Icons.check_box_outlined)),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

