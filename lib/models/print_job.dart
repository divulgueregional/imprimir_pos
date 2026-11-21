import 'package:intl/intl.dart';

enum PrintJobStatus { success, error, pending }

class PrintJob {
  final String id;
  final DateTime timestamp;
  final String printerName;
  final String docName;
  final int byteCount;
  final PrintJobStatus status;
  final String? errorMessage;

  PrintJob({
    required this.id,
    required this.timestamp,
    required this.printerName,
    required this.docName,
    required this.byteCount,
    required this.status,
    this.errorMessage,
  });

  String get formattedTime => DateFormat('HH:mm:ss - dd/MM/yyyy').format(timestamp);

  String get formattedSize {
    if (byteCount < 1024) return '$byteCount B';
    return '${(byteCount / 1024).toStringAsFixed(1)} KB';
  }
}
