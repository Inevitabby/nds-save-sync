import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

// STATES
// 
// 1. Disconnected (Idle):
//  - Condition: Initial state, no "last IP" recorded
//  - Hero: "Search for Device" (TODO wording)
// 
// 2. Scanning:
//  - Condition: Previous button pressed, OR app started with a "last IP" recorded
//  - Hero: Some pinging/loading indicator "Connecting to your DS..." (TODO this wording is misleading)
//  - Fail:
//    - Condition: User doesn't have WiFi OR Hotspot (instafail)
//    -            Or, we couldn't find the DS on WiFi or Hotspot subnet 
//    - Hero: TODO Should there be two different fail messages? One that is a gentle like modal with a few bullet points or something like, "Couldn't find DS 1. Is your phone and DS on the same hotspot or WiFi? 2. If your DS's FTP app running? etc." And have like two buttons like, "Let me try again" or "Let me enter the IP manually"
// 
// 3. First-Time Connect (Path Picker):
//  - Condition: Found the DS but have no saveDir
//  - Hero: Slide-up modal showing FTP directory browser, user finds and picks folder
//          At this point, we will update the LAST_IP
// 
// 4. Ready (Connected): 
//  - Hero: "Tap to Sync"
// 
// 5. Working
//  - Hero: Some sort of live log. The *bulk* of time will be waiting on the crap link so a "Currently downloading" would be nice. (TODO: Design this a bit better)
// 
// 6. Success:
//  - Hero: Green button

// OTHER LOCATIONS
// - Left: Save Archive
// - Right: Settings xor Debug (Version Information and Logs (?))

enum DashboardState { idle, scanning, connected, working, success }

class _DashboardState extends State<Dashboard> {
  DashboardState _dashboardState = DashboardState.idle;
  String? _saveDir;

  @override
  Widget build(BuildContext context) {
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
