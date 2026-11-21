import 'dart:io';
import 'package:flutter/material.dart';
import 'services/local_server.dart';
import 'services/settings_service.dart';
import 'services/tray_service.dart';
import 'services/windows_raw_printer.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar configurações persistidas
  final settingsService = SettingsService();
  await settingsService.init();

  // 2. Inicializar o servidor HTTP / WebSocket local (127.0.0.1:8182)
  final localServer = LocalServer(settingsService: settingsService);
  await localServer.start();

  // 3. Inicializar a bandeja do sistema (System Tray) e gerenciador de janela
  TrayService? trayService;
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    trayService = TrayService(
      settingsService: settingsService,
      onTestPrint: () async {
        final printer = settingsService.selectedPrinter;
        if (printer != null && printer.isNotEmpty) {
          final bytes = WindowsRawPrinter.generateTestEscPosTicket(printer);
          await WindowsRawPrinter.printRawBytes(printer, bytes, docName: 'Teste Bandeja DRSystema');
        }
      },
    );
    await trayService.init();
  }

  runApp(DRSystemaPrintApp(
    server: localServer,
    settings: settingsService,
  ));
}

class DRSystemaPrintApp extends StatelessWidget {
  final LocalServer server;
  final SettingsService settings;

  const DRSystemaPrintApp({
    super.key,
    required this.server,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DRSystema Print',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: HomePage(
        server: server,
        settings: settings,
      ),
    );
  }
}
