import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const _keyPrinter = 'selected_printer';
  static const _keyPort = 'server_port';
  static const _keyAutostart = 'autostart';
  static const _keyMinimizeToTray = 'minimize_to_tray';

  SharedPreferences? _prefs;

  String? _selectedPrinter;
  int _port = 8182;
  bool _autostart = true;
  bool _minimizeToTray = true;

  String? get selectedPrinter => _selectedPrinter;
  int get port => _port;
  bool get autostart => _autostart;
  bool get minimizeToTray => _minimizeToTray;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _selectedPrinter = _prefs?.getString(_keyPrinter);
    _port = _prefs?.getInt(_keyPort) ?? 8182;
    _autostart = _prefs?.getBool(_keyAutostart) ?? true;
    _minimizeToTray = _prefs?.getBool(_keyMinimizeToTray) ?? true;

    if (Platform.isWindows) {
      await _initLaunchAtStartup();
    }

    notifyListeners();
  }

  Future<void> _initLaunchAtStartup() async {
    try {
      launchAtStartup.setup(
        appName: 'DRSystema Print',
        appPath: Platform.resolvedExecutable,
      );

      if (_autostart) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    } catch (e) {
      debugPrint('Erro ao configurar inicializacao automatica: $e');
    }
  }

  Future<void> setSelectedPrinter(String? printer) async {
    _selectedPrinter = printer;
    if (printer == null) {
      await _prefs?.remove(_keyPrinter);
    } else {
      await _prefs?.setString(_keyPrinter, printer);
    }
    notifyListeners();
  }

  Future<void> setPort(int port) async {
    _port = port;
    await _prefs?.setInt(_keyPort, port);
    notifyListeners();
  }

  Future<void> setAutostart(bool enable) async {
    _autostart = enable;
    await _prefs?.setBool(_keyAutostart, enable);

    if (Platform.isWindows) {
      try {
        if (enable) {
          await launchAtStartup.enable();
        } else {
          await launchAtStartup.disable();
        }
      } catch (e) {
        debugPrint('Erro ao alterar autostart: $e');
      }
    }

    notifyListeners();
  }

  Future<void> setMinimizeToTray(bool enable) async {
    _minimizeToTray = enable;
    await _prefs?.setBool(_keyMinimizeToTray, enable);
    notifyListeners();
  }
}
