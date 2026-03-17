import 'package:shared_preferences/shared_preferences.dart';

class Persistence {
  static const _keyLastIp           = 'last_ip';
  static const _keyLastPort         = 'last_port';
  static const _keySaveDir          = 'save_dir';
  static const _keyArchiveUri       = 'archive_uri';
  static const _keyOnboardingDone   = 'onboarding_complete';

  static Future<PersistedState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PersistedState(
      lastIp:          prefs.getString(_keyLastIp),
      lastPort:        prefs.getInt(_keyLastPort),
      saveDir:         prefs.getString(_keySaveDir),
      archiveUri:      prefs.getString(_keyArchiveUri),
      onboardingDone:  prefs.getBool(_keyOnboardingDone) ?? false,
    );
  }

  static Future<void> saveLastIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastIp, ip);
  }

  static Future<void> saveLastPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastPort, port);
  }

  static Future<void> saveSaveDir(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySaveDir, path);
  }

  static Future<void> saveArchiveUri(String uri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyArchiveUri, uri);
  }

  static Future<void> setOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingDone, true);
  }
}

class PersistedState {
  const PersistedState({
    this.lastIp,
    this.lastPort,
    this.saveDir,
    this.archiveUri,
    this.onboardingDone = false,
  });

  final String? lastIp;
  final int? lastPort;
  final String? saveDir;
  final String? archiveUri;
  final bool onboardingDone;
}
