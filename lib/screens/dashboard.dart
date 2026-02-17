import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/providers/dashboard_controller.dart';

// STATES
// 
// 1. Idle (Disconnected):
//  - Condition: Initial state, lastAddr is null
//  - Hero: "Search for Device" (TODO wording)
// 
// 2. Scanning:
//  - Condition: Button pressed OR app started with lastAddr not null
//  - Hero: Some loading indicator "Connecting to your DS..." (TODO this wording is misleading)
//  - Fail:
//    - Condition: User not on WiFi OR Hotspot (instafail)
//    -            OR we couldn't find the DS on WiFi/Hotspot subnet 
//    - Hero: TODO (Should there be two different fail messages? One that is a gentle like modal with a few bullet points or something like, "Couldn't find DS 1. Is your phone and DS on the same hotspot or WiFi? 2. If your DS's FTP app running? etc." And have like two buttons like, "Let me try again" or "Let me enter the IP manually")
// 
// 3. Connected:
//  - Condition: Connection established to DS.
//  - Case A: First-Connection (saveDir is null)
//    - Hero: Slide-up modal showing FTP directory browser, user finds and picks saveDir folder
//  - Case B: Ready (saveDir not null)_
//    - Hero: "Tap to Sync"
// 
// 4. Working
//  - Condition: Sync started
//  - Hero: Some sort of live log/progress indicator. The *bulk* of time will be waiting on the crap link so this'll need to be good. (TODO Design this)
// 
// 5. Success:
//  - Condition: Sync completed
//  - Hero: TODO Some sort of success indicator and something telling the user to check their archive. i.e., "Swipe left to see saves" or something

// OTHER LOCATIONS
// - Left: Save Archive
// - Right: Settings xor Debug (Version Information and Logs (TODO Plan this side))

class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(border: BoxBorder.all(color: colorScheme.primary ) ),
                child: const Center(child: Text("Network")),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(border: BoxBorder.all(color: colorScheme.primary ) ),
                child: const Center(child: Text("Hero")),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(border: BoxBorder.all(color: colorScheme.primary ) ),
                child: const Center(child: Text("Notifications")),
              ),
            ),
            Expanded( // TODO Left: Save Archive, Right: Settings
              flex: 1,
              child: Container(
                decoration: BoxDecoration(border: BoxBorder.all(color: colorScheme.primary ) ),
                child: const Center(child: Text("Slider Indicators")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
