import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the demo session lifecycle and persistence.
///
/// When in demo mode, the application runs entirely against isolated demo storage
/// and demo state, completely detached from production Firebase and local production cache.
class DemoSessionManager extends ChangeNotifier {
  DemoSessionManager._();

  static final DemoSessionManager instance = DemoSessionManager._();
  static const String _prefKey = 'haven_is_demo_session_active';

  bool _isDemoMode = false;
  bool _initialized = true;

  bool get isDemoMode => _isDemoMode;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey) ?? false;
      if (_isDemoMode != saved) {
        _isDemoMode = saved;
        notifyListeners();
      }
    } catch (e) {
      _isDemoMode = false;
    }
  }

  Future<void> enterDemoMode() async {
    _isDemoMode = true;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> exitDemoMode() async {
    _isDemoMode = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, false);
    } catch (_) {}
    notifyListeners();
  }
}
