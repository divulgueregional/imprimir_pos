// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/legacy.dart';
import 'settings_service.dart';

class TrayService with TrayListener, WindowListener {
  final SettingsService settingsService;
  final VoidCallback? onTestPrint;

  TrayService({
    required this.settingsService,
    this.onTestPrint,
  });

  Future<void> init() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;

    // 1. Inicializar window_manager
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(820, 680),
      minimumSize: Size(700, 550),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'DRSystema Print',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    windowManager.addListener(this);

    // 2. Inicializar tray_manager
    try {
      trayManager.addListener(this);

      final iconPath = Platform.isWindows
          ? 'windows/runner/resources/app_icon.ico'
          : 'assets/icons/app_icon.png';

      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('DRSystema Print - Servidor Ativo');

      await updateContextMenu();
    } catch (e) {
      debugPrint('Aviso: Falha ao carregar bandeja do sistema: $e');
    }
  }

  Future<void> updateContextMenu() async {
    try {
      final menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Abrir DRSystema Print',
          ),
          MenuItem(
            key: 'test_print',
            label: 'Imprimir Cupom de Teste',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Encerrar Aplicativo',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (_) {}
  }

  @override
  void onWindowClose() async {
    if (settingsService.minimizeToTray) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  @override
  void onTrayIconMouseDown() async {
    await showWindow();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_window':
        await showWindow();
        break;
      case 'test_print':
        onTestPrint?.call();
        break;
      case 'exit_app':
        await windowManager.destroy();
        exit(0);
    }
  }

  Future<void> showWindow() async {
    final isVisible = await windowManager.isVisible();
    if (!isVisible) {
      await windowManager.show();
    }
    await windowManager.focus();
  }

  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }
}
