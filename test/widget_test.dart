import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drsystema_print/models/print_request.dart';

void main() {
  test('PrintRequest decodifica base64 corretamente', () {
    const rawText = 'TESTE IMPRESSAO';
    final base64String = base64Encode(utf8.encode(rawText));

    final req = PrintRequest(
      printer: 'Elgin I8',
      data: base64String,
      type: 'raw',
    );

    final bytes = req.toBytes();
    expect(utf8.decode(bytes), equals(rawText));
  });

  test('PrintRequest processa JSON array do QZ Tray', () {
    const rawText = 'ESC/POS BYTES';
    final base64String = base64Encode(utf8.encode(rawText));

    final qzArrayPayload = [
      {
        'type': 'raw',
        'format': 'base64',
        'data': base64String,
      }
    ];

    final req = PrintRequest.fromJson(qzArrayPayload, defaultPrinter: 'Elgin I8');
    expect(req.printer, equals('Elgin I8'));
    expect(req.type, equals('raw'));
    expect(utf8.decode(req.toBytes()), equals(rawText));
  });
}
