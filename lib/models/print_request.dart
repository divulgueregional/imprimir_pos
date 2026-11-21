import 'dart:convert';
import 'dart:typed_data';

/// Modelo da requisição de impressão recebida via HTTP ou WebSocket
class PrintRequest {
  /// Nome da impressora (opcional se houver uma impressora padrão configurada)
  final String? printer;

  /// String Base64 dos dados binários ESC/POS
  final String data;

  /// Tipo de dado: 'raw', 'base64', 'escpos', etc.
  final String type;

  /// Nome do trabalho/documento no Spooler do Windows
  final String docName;

  /// Encoding dos caracteres (ex: 'Cp1252')
  final String encoding;

  PrintRequest({
    this.printer,
    required this.data,
    this.type = 'raw',
    this.docName = 'DRSystema Cupom NFCe',
    this.encoding = 'Cp1252',
  });

  /// Converte a string Base64 em bytes binários prontos para o Spooler
  Uint8List toBytes() {
    try {
      // Limpar possíveis espaços ou quebras de linha na string base64
      final sanitized = data.trim().replaceAll(RegExp(r'\s+'), '');
      return base64Decode(sanitized);
    } catch (e) {
      throw FormatException('Falha ao decodificar dados Base64: $e');
    }
  }

  /// Cria a requisição a partir de um JSON simples
  /// Suporta tanto o formato do DRSystema quanto o formato array nativo do QZ Tray
  factory PrintRequest.fromJson(dynamic json, {String? defaultPrinter}) {
    if (json is List && json.isNotEmpty) {
      // Suporte ao formato de array do QZ Tray: [{type: 'raw', format: 'base64', data: '...'}]
      final firstItem = json.first;
      if (firstItem is Map) {
        return PrintRequest(
          printer: defaultPrinter,
          data: firstItem['data']?.toString() ?? '',
          type: firstItem['type']?.toString() ?? 'raw',
        );
      }
    }

    if (json is Map<String, dynamic>) {
      return PrintRequest(
        printer: json['printer']?.toString() ?? defaultPrinter,
        data: json['data']?.toString() ?? json['conteudo']?.toString() ?? '',
        type: json['type']?.toString() ?? 'raw',
        docName: json['docName']?.toString() ?? json['doc_name']?.toString() ?? 'DRSystema Cupom NFCe',
        encoding: json['encoding']?.toString() ?? 'Cp1252',
      );
    }

    throw const FormatException('Payload JSON inválido para impressão');
  }

  Map<String, dynamic> toJson() => {
    'printer': printer,
    'type': type,
    'docName': docName,
    'encoding': encoding,
  };
}
