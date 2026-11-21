// ignore_for_file: camel_case_types

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// Structs Win32 necessárias para impressão RAW via Spooler do Windows
final class DOC_INFO_1W extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

final class PRINTER_INFO_4W extends Struct {
  external Pointer<Utf16> pPrinterName;
  external Pointer<Utf16> pServerName;
  @Uint32()
  external int attributes;
}

/// Serviço de Impressão RAW nativo do Windows (comunicação direta com winspool.drv)
class WindowsRawPrinter {
  static DynamicLibrary? _winspool;
  static DynamicLibrary? _kernel32;

  // Assinaturas de funções de winspool.drv
  static int Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>)? _openPrinter;
  static int Function(int, int, Pointer<DOC_INFO_1W>)? _startDocPrinter;
  static int Function(int)? _startPagePrinter;
  static int Function(int, Pointer<Uint8>, int, Pointer<Uint32>)? _writePrinter;
  static int Function(int)? _endPagePrinter;
  static int Function(int)? _endDocPrinter;
  static int Function(int)? _closePrinter;
  static int Function(int, Pointer<Utf16>, int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Uint32>)? _enumPrinters;
  static int Function()? _getLastError;

  static bool _initialized = false;

  /// Inicializa as ligações FFI nativas do Windows
  static void _initNativeBindings() {
    if (_initialized) return;
    if (!Platform.isWindows) {
      _initialized = true;
      return;
    }

    try {
      _winspool = DynamicLibrary.open('winspool.drv');
      _kernel32 = DynamicLibrary.open('kernel32.dll');

      _openPrinter = _winspool!
          .lookupFunction<Int32 Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>),
              int Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>)>('OpenPrinterW');

      _startDocPrinter = _winspool!
          .lookupFunction<Uint32 Function(IntPtr, Uint32, Pointer<DOC_INFO_1W>),
              int Function(int, int, Pointer<DOC_INFO_1W>)>('StartDocPrinterW');

      _startPagePrinter = _winspool!
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>('StartPagePrinter');

      _writePrinter = _winspool!
          .lookupFunction<Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>),
              int Function(int, Pointer<Uint8>, int, Pointer<Uint32>)>('WritePrinter');

      _endPagePrinter = _winspool!
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>('EndPagePrinter');

      _endDocPrinter = _winspool!
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>('EndDocPrinter');

      _closePrinter = _winspool!
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>('ClosePrinter');

      _enumPrinters = _winspool!
          .lookupFunction<
              Int32 Function(Uint32, Pointer<Utf16>, Uint32, Pointer<Uint8>, Uint32, Pointer<Uint32>, Pointer<Uint32>),
              int Function(int, Pointer<Utf16>, int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Uint32>)>('EnumPrintersW');

      _getLastError = _kernel32!
          .lookupFunction<Uint32 Function(), int Function()>('GetLastError');

      _initialized = true;
    } catch (e) {
      // Ignora erro em plataformas não Windows ou falha de carregamento
      _initialized = true;
    }
  }

  /// Lista todas as impressoras disponíveis no Windows
  static Future<List<String>> getPrinters() async {
    _initNativeBindings();

    if (!Platform.isWindows) {
      return _getPrintersFallbackNonWindows();
    }

    // 1. Tentar via EnumPrintersW nativo (FFI)
    try {
      final ffiPrinters = _getPrintersViaFFI();
      if (ffiPrinters.isNotEmpty) {
        return ffiPrinters;
      }
    } catch (_) {}

    // 2. Fallback seguro via PowerShell no Windows
    return await _getPrintersViaPowerShell();
  }

  static List<String> _getPrintersViaFFI() {
    if (_enumPrinters == null) return [];

    const flags = 0x00000002 | 0x00000004; // PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS
    const level = 4; // PRINTER_INFO_4W

    final pcbNeeded = calloc<Uint32>();
    final pcReturned = calloc<Uint32>();

    try {
      // Primeira chamada para calcular o tamanho de buffer necessário
      _enumPrinters!(flags, nullptr, level, nullptr, 0, pcbNeeded, pcReturned);

      final bufferSize = pcbNeeded.value;
      if (bufferSize == 0) return [];

      final pBuffer = calloc<Uint8>(bufferSize);
      try {
        final result = _enumPrinters!(flags, nullptr, level, pBuffer, bufferSize, pcbNeeded, pcReturned);
        if (result != 0) {
          final count = pcReturned.value;
          final printers = <String>[];
          final pInfo = pBuffer.cast<PRINTER_INFO_4W>();

          for (var i = 0; i < count; i++) {
            final info = (pInfo + i).ref;
            if (info.pPrinterName != nullptr) {
              final name = info.pPrinterName.toDartString();
              if (name.isNotEmpty) {
                printers.add(name);
              }
            }
          }
          return printers;
        }
      } finally {
        calloc.free(pBuffer);
      }
    } finally {
      calloc.free(pcbNeeded);
      calloc.free(pcReturned);
    }

    return [];
  }

  static Future<List<String>> _getPrintersViaPowerShell() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-CimInstance Win32_Printer | Select-Object -ExpandProperty Name'
      ]);

      if (result.exitCode == 0) {
        final lines = (result.stdout as String)
            .split(RegExp(r'[\r\n]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          return lines;
        }
      }
    } catch (_) {}

    return ['Elgin I8', 'Microsoft Print to PDF'];
  }

  static List<String> _getPrintersFallbackNonWindows() {
    return [
      'Elgin I8 (Simulador)',
      'EPSON TM-T20 (Simulador)',
      'Bematech MP-4200 (Simulador)',
      'Microsoft Print to PDF'
    ];
  }

  /// Envia um array de bytes diretamente para a impressora em modo RAW
  static Future<void> printRawBytes(
    String printerName,
    Uint8List bytes, {
    String docName = 'DRSystema NFCe',
  }) async {
    _initNativeBindings();

    if (bytes.isEmpty) {
      throw Exception('Não há dados binários para impressão');
    }

    if (!Platform.isWindows) {
      // Simulação em ambiente de desenvolvimento macOS/Linux
      await Future.delayed(const Duration(milliseconds: 150));
      return;
    }

    if (_openPrinter == null || _startDocPrinter == null || _writePrinter == null) {
      throw Exception('Biblioteca winspool.drv não pôde ser carregada');
    }

    final pPrinterName = printerName.toNativeUtf16();
    final phPrinter = calloc<IntPtr>();

    try {
      // 1. OpenPrinterW
      final openResult = _openPrinter!(pPrinterName, phPrinter, nullptr);
      if (openResult == 0) {
        final errorCode = _getLastError?.call() ?? 0;
        throw Exception('Falha ao abrir impressora "$printerName" (Código: $errorCode). Verifique se está ligada e instalada.');
      }

      final hPrinter = phPrinter.value;
      final pDocName = docName.toNativeUtf16();
      final pDatatype = 'RAW'.toNativeUtf16(); // OBRIGATÓRIO: modo RAW para comandos ESC/POS
      final docInfo = calloc<DOC_INFO_1W>();

      docInfo.ref.pDocName = pDocName;
      docInfo.ref.pOutputFile = nullptr;
      docInfo.ref.pDatatype = pDatatype;

      try {
        // 2. StartDocPrinterW
        final jobId = _startDocPrinter!(hPrinter, 1, docInfo);
        if (jobId == 0) {
          final errorCode = _getLastError?.call() ?? 0;
          throw Exception('Falha ao iniciar documento de impressão RAW (Código: $errorCode)');
        }

        try {
          // 3. StartPagePrinter
          _startPagePrinter?.call(hPrinter);

          // 4. WritePrinter
          final pBytes = calloc<Uint8>(bytes.length);
          final pcWritten = calloc<Uint32>();

          try {
            // Copiar bytes para a memória nativa
            pBytes.asTypedList(bytes.length).setAll(0, bytes);

            final writeResult = _writePrinter!(hPrinter, pBytes, bytes.length, pcWritten);
            if (writeResult == 0) {
              final errorCode = _getLastError?.call() ?? 0;
              throw Exception('Erro ao enviar bytes para a porta da impressora (Código: $errorCode)');
            }
          } finally {
            calloc.free(pBytes);
            calloc.free(pcWritten);
            // 5. EndPagePrinter
            _endPagePrinter?.call(hPrinter);
          }
        } finally {
          // 6. EndDocPrinter
          _endDocPrinter?.call(hPrinter);
        }
      } finally {
        calloc.free(pDocName);
        calloc.free(pDatatype);
        calloc.free(docInfo);
        // 7. ClosePrinter
        _closePrinter?.call(hPrinter);
      }
    } finally {
      calloc.free(pPrinterName);
      calloc.free(phPrinter);
    }
  }

  /// Gera um cupom de teste formatado em comandos ESC/POS (80mm) com corte de papel
  static Uint8List generateTestEscPosTicket(String printerName) {
    final buffer = BytesBuilder();

    // ESC @: Inicializar impressora
    buffer.add([0x1B, 0x40]);

    // ESC a 1: Alinhamento Centralizado
    buffer.add([0x1B, 0x61, 0x01]);

    // ESC E 1: Negrito LIGADO
    buffer.add([0x1B, 0x45, 0x01]);
    buffer.add(utf8.encode('DRSystema Print\n'));
    buffer.add(utf8.encode('SERVICO LOCAL DE IMPRESSAO\n'));

    // ESC E 0: Negrito DESLIGADO
    buffer.add([0x1B, 0x45, 0x00]);
    buffer.add(utf8.encode('Substituto nativo do QZ Tray\n'));
    buffer.add(utf8.encode('------------------------------------------------\n'));

    // ESC a 0: Alinhamento a Esquerda
    buffer.add([0x1B, 0x61, 0x00]);
    buffer.add(utf8.encode('Impressora: $printerName\n'));
    buffer.add(utf8.encode('Modo: RAW (Comandos Diretos ESC/POS)\n'));
    buffer.add(utf8.encode('Data/Hora: ${DateTime.now().toLocal().toString().split('.')[0]}\n'));
    buffer.add(utf8.encode('Status: COMUNICACAO BEM-SUCEDIDA!\n'));
    buffer.add(utf8.encode('Suporte a NFC-e (65) e NF-e (55)\n'));

    // ESC a 1: Centralizado
    buffer.add([0x1B, 0x61, 0x01]);
    buffer.add(utf8.encode('------------------------------------------------\n'));
    buffer.add(utf8.encode('DRSystema - Solucoes Fiscais e PDV\n'));
    buffer.add(utf8.encode('www.drsystema.com.br\n\n\n\n'));

    // GS V 66 0: Corte parcial do papel (ou GS V 1 para corte total)
    buffer.add([0x1D, 0x56, 0x42, 0x00]);

    return buffer.toBytes();
  }
}
