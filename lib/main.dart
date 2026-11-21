import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'services/local_server.dart';
import 'services/settings_service.dart';
import 'services/tray_service.dart';
import 'services/windows_raw_printer.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar configurações persistidas
  final settingsService = SettingsService();
  await settingsService.init();

  // 2. Se já houver outra instância respondendo na porta, encerra
  //    silenciosamente (a janela continua na bandeja da instância ativa)
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    if (await _isAlreadyRunning(settingsService.port)) exit(0);
  }

  // 3. Inicializar o servidor HTTP / WebSocket local (127.0.0.1:8182)
  final localServer = LocalServer(settingsService: settingsService);
  await localServer.start();

  // 4. Inicializar a bandeja do sistema (System Tray) e gerenciador de janela
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
    // '--minimized' vem do autostart do Windows: abre direto na bandeja
    await trayService.init(startMinimized: args.contains('--minimized'));
  }

  runApp(DRSystemaPrintApp(
    server: localServer,
    settings: settingsService,
  ));
}

/// Verifica se já existe outra instância do DRSystema Print respondendo
/// no endpoint /status (evita abrir o app duplicado).
Future<bool> _isAlreadyRunning(int port) async {
  try {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 1);
    final request =
        await client.getUrl(Uri.parse('http://127.0.0.1:$port/status'));
    final response =
        await request.close().timeout(const Duration(seconds: 1));
    final body = await utf8.decoder.bind(response).join();
    client.close(force: true);
    final data = jsonDecode(body);
    return data is Map && data['app'] == 'DRSystema Print';
  } catch (_) {
    return false;
  }
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
