import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Controle da janela principal no Windows via Win32 (user32.dll).
///
/// Usado porque a resolução de janela do window_manager/nativeapi não é
/// confiável quando a chamada sai de uma thread diferente da que criou o HWND.
class WindowsWindow {
  static const _propMinimizeToTray = 'DRSYS_MINIMIZE_TO_TRAY';
  static const _swHide = 0;
  static const _swRestore = 9;

  static DynamicLibrary? _user32;
  static int Function(Pointer<Utf16>, Pointer<Utf16>)? _findWindow;
  static int Function(int, int)? _showWindow;
  static int Function(int)? _setForegroundWindow;
  static int Function(int, Pointer<Utf16>, int)? _setProp;

  static void _ensureInit() {
    if (_user32 != null || !Platform.isWindows) return;
    _user32 = DynamicLibrary.open('user32.dll');
    _findWindow = _user32!.lookupFunction<
        IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
        int Function(Pointer<Utf16>, Pointer<Utf16>)>('FindWindowW');
    _showWindow = _user32!.lookupFunction<Int32 Function(IntPtr, Int32),
        int Function(int, int)>('ShowWindow');
    _setForegroundWindow = _user32!
        .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'SetForegroundWindow');
    _setProp = _user32!.lookupFunction<
        Int32 Function(IntPtr, Pointer<Utf16>, IntPtr),
        int Function(int, Pointer<Utf16>, int)>('SetPropW');
  }

  /// Localiza o HWND da janela principal pelo título.
  static int _findMainWindow() {
    _ensureInit();
    if (_findWindow == null) return 0;
    final title = 'DRSystema Print'.toNativeUtf16();
    try {
      return _findWindow!(nullptr.cast<Utf16>(), title);
    } finally {
      calloc.free(title);
    }
  }

  /// Mostra e traz a janela para frente (reabrir a partir da bandeja).
  static void showMainWindow() {
    final hwnd = _findMainWindow();
    if (hwnd == 0) return;
    _showWindow!(hwnd, _swRestore);
    _setForegroundWindow!(hwnd);
  }

  /// Oculta a janela sem destruí-la (servidor segue rodando).
  static void hideMainWindow() {
    final hwnd = _findMainWindow();
    if (hwnd == 0) return;
    _showWindow!(hwnd, _swHide);
  }

  /// Grava na janela a preferência "minimizar para a bandeja ao fechar".
  /// O runner C++ lê essa prop no WM_CLOSE para decidir ocultar ou encerrar.
  static void setMinimizeToTray(bool enabled) {
    final hwnd = _findMainWindow();
    if (hwnd == 0) return;
    final name = _propMinimizeToTray.toNativeUtf16();
    try {
      _setProp!(hwnd, name, enabled ? 1 : 0);
    } finally {
      calloc.free(name);
    }
  }
}
