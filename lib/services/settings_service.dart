import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const _keyPrinter = 'selected_printer';
  static const _keyPort = 'server_port';
  static const _keyAutostart = 'autostart';
  static const _keyMinimizeToTray = 'minimize_to_tray';
  static const _keyApiUrlXml = 'api_url_xml';

  /// URL padrão do endpoint PHP que converte XML fiscal em ESC/POS.
  /// Vazia de propósito: cada instalação configura a própria API
  /// (o instalador pergunta; também pode ser digitada nas Preferências).
  static const defaultApiUrlXml = '';

  SharedPreferences? _prefs;

  String? _selectedPrinter;
  int _port = 8182;
  bool _autostart = true;
  bool _minimizeToTray = true;
  String _apiUrlXml = defaultApiUrlXml;

  String? get selectedPrinter => _selectedPrinter;
  int get port => _port;
  bool get autostart => _autostart;
  bool get minimizeToTray => _minimizeToTray;
  String get apiUrlXml => _apiUrlXml;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _selectedPrinter = _prefs?.getString(_keyPrinter);
    _port = _prefs?.getInt(_keyPort) ?? 8182;
    _autostart = _prefs?.getBool(_keyAutostart) ?? true;
    _minimizeToTray = _prefs?.getBool(_keyMinimizeToTray) ?? true;
    _apiUrlXml = _prefs?.getString(_keyApiUrlXml) ?? defaultApiUrlXml;

    // O instalador pode gravar `api_url.txt` ao lado do .exe com a URL
    // escolhida na tela de configuração — importa uma vez e apaga.
    await _importInstallerApiUrl();

    if (Platform.isWindows) {
      await _initLaunchAtStartup();
    }

    notifyListeners();
  }

  /// Lê `api_url.txt` gravado pelo instalador ao lado do executável,
  /// aplica como URL da API de conversão XML e remove o arquivo.
  Future<void> _importInstallerApiUrl() async {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final urlFile = File('$exeDir${Platform.pathSeparator}api_url.txt');
      if (await urlFile.exists()) {
        final url = (await urlFile.readAsString()).trim();
        if (url.isNotEmpty) {
          _apiUrlXml = url;
          await _prefs?.setString(_keyApiUrlXml, url);
        }
        await urlFile.delete();
      }
    } catch (_) {
      // Sem arquivo ou sem permissão — segue com o que houver nas prefs
    }
  }

  Future<void> _initLaunchAtStartup() async {
    try {
      launchAtStartup.setup(
        appName: 'DRSystema Print',
        appPath: Platform.resolvedExecutable,
        // Ao iniciar com o Windows, abre direto na bandeja (sem janela).
        args: const ['--minimized'],
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

  Future<void> setApiUrlXml(String url) async {
    _apiUrlXml = url.trim();
    await _prefs?.setString(_keyApiUrlXml, _apiUrlXml);
    notifyListeners();
  }
}
