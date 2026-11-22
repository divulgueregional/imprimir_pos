import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/print_job.dart';
import '../models/print_request.dart';
import 'settings_service.dart';
import 'windows_raw_printer.dart';

class LocalServer extends ChangeNotifier {
  final SettingsService settingsService;

  HttpServer? _server;
  bool _isRunning = false;
  String? _lastError;

  final List<PrintJob> _history = [];
  final _historyController = StreamController<List<PrintJob>>.broadcast();

  LocalServer({required this.settingsService});

  bool get isRunning => _isRunning;
  int get port => settingsService.port;
  String? get lastError => _lastError;
  List<PrintJob> get history => List.unmodifiable(_history);
  Stream<List<PrintJob>> get historyStream => _historyController.stream;

  /// Inicia o servidor HTTP e WebSocket na porta configurada
  Future<void> start() async {
    if (_isRunning) return;

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        settingsService.port,
        shared: true,
      );

      _isRunning = true;
      _lastError = null;
      notifyListeners();

      debugPrint('DRSystema Print Server rodando em http://127.0.0.1:${settingsService.port}');

      _server!.listen(
        _handleRequest,
        onError: (e) {
          _lastError = 'Erro no servidor: $e';
          _isRunning = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _isRunning = false;
      _lastError = 'Falha ao iniciar servidor na porta ${settingsService.port}: $e';
      notifyListeners();
      debugPrint(_lastError);
    }
  }

  /// Para o servidor
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _isRunning = false;
    notifyListeners();
  }

  /// Reinicia o servidor (útil ao mudar de porta)
  Future<void> restart() async {
    await stop();
    await start();
  }

  /// Trata todas as requisições HTTP e WebSocket
  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    // Configuração obrigatória de CORS e PNA (Private Network Access) para Chrome/Edge
    _applyCorsAndPnaHeaders(response);

    // 1. Preflight OPTIONS (Navegadores mandam antes de requisições POST)
    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    // 2. Conexão WebSocket (Se a página web preferir ws://127.0.0.1:8182)
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      await _handleWebSocket(request);
      return;
    }

    final path = request.uri.path.toLowerCase();

    try {
      // 3. Rotas HTTP REST
      if (request.method == 'GET' && (path == '/' || path == '/status' || path == '/ping')) {
        await _handleStatus(request);
      } else if (request.method == 'GET' && path == '/printers') {
        await _handleGetPrinters(request);
      } else if (request.method == 'POST' && (path == '/print' || path == '/imprimir')) {
        await _handlePostPrint(request);
      } else {
        response.statusCode = HttpStatus.notFound;
        response.write(jsonEncode({'sucesso': false, 'erro': 'Endpoint não encontrado: $path'}));
        await response.close();
      }
    } catch (e, stack) {
      debugPrint('Erro ao processar requisição: $e\n$stack');
      response.statusCode = HttpStatus.internalServerError;
      response.write(jsonEncode({'sucesso': false, 'erro': e.toString()}));
      await response.close();
    }
  }

  /// Injeta os cabeçalhos essenciais para contornar Mixed-Content e PNA
  void _applyCorsAndPnaHeaders(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
    response.headers.set('Access-Control-Allow-Private-Network', 'true');
    response.headers.set('Access-Control-Max-Age', '86400');
    response.headers.set('Content-Type', 'application/json; charset=utf-8');
  }

  /// Endpoint GET /status
  Future<void> _handleStatus(HttpRequest request) async {
    final body = jsonEncode({
      'sucesso': true,
      'status': 'online',
      'app': 'DRSystema Print',
      'versao': '1.0.0',
      'porta': settingsService.port,
      'impressora_padrao': settingsService.selectedPrinter,
    });
    request.response.write(body);
    await request.response.close();
  }

  /// Endpoint GET /printers
  Future<void> _handleGetPrinters(HttpRequest request) async {
    final printers = await WindowsRawPrinter.getPrinters();
    final body = jsonEncode({
      'sucesso': true,
      'impressoras': printers,
      'padrao': settingsService.selectedPrinter ?? (printers.isNotEmpty ? printers.first : null),
    });
    request.response.write(body);
    await request.response.close();
  }

  /// Endpoint POST /print (Recebe a NFC-e em Base64 e despacha para a Elgin I8)
  Future<void> _handlePostPrint(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    if (content.trim().isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'sucesso': false, 'erro': 'Corpo da requisição vazio'}));
      await request.response.close();
      return;
    }

    dynamic jsonPayload;
    try {
      jsonPayload = jsonDecode(content);
    } catch (_) {
      // Se não for JSON, pode ser a string Base64 direta
      jsonPayload = {'data': content.trim(), 'type': 'raw'};
    }

    final printReq = PrintRequest.fromJson(
      jsonPayload,
      defaultPrinter: settingsService.selectedPrinter,
    );

    final (targetPrinter, aviso) = await _resolvePrinter(printReq.printer);

    if (targetPrinter == null || targetPrinter.isEmpty) {
      final printers = await WindowsRawPrinter.getPrinters();
      if (printers.isNotEmpty) {
        // Fallback para a primeira impressora encontrada
        await _executePrint(printers.first, printReq, request.response);
        return;
      }

      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({
        'sucesso': false,
        'erro': 'Nenhuma impressora informada ou configurada como padrão no DRSystema Print'
      }));
      await request.response.close();
      return;
    }

    await _executePrint(targetPrinter, printReq, request.response, aviso: aviso);
  }

  /// Resolve a impressora alvo validando o nome pedido contra as instaladas.
  /// Se o nome não existir no Windows, cai na impressora padrão (ou na
  /// primeira instalada) e devolve um aviso do redirecionamento.
  Future<(String?, String?)> _resolvePrinter(String? requested) async {
    final installed = await WindowsRawPrinter.getPrinters();
    if (installed.isEmpty) return (requested, null);

    String? canon(String? name) {
      if (name == null) return null;
      for (final p in installed) {
        if (p.toLowerCase() == name.toLowerCase()) return p;
      }
      return null;
    }

    var target = canon(requested);
    if (target != null) return (target, null);

    target = canon(settingsService.selectedPrinter) ?? installed.first;
    final aviso = (requested != null && requested.isNotEmpty)
        ? 'Impressora "$requested" não encontrada; impresso em "$target"'
        : null;
    return (target, aviso);
  }

  /// Executa o envio binário para a impressora
  Future<void> _executePrint(String printerName, PrintRequest request, HttpResponse response, {String? aviso}) async {
    final jobId = DateTime.now().millisecondsSinceEpoch.toString();
    Uint8List bytes;

    try {
      bytes = request.toBytes();
    } catch (e) {
      final job = PrintJob(
        id: jobId,
        timestamp: DateTime.now(),
        printerName: printerName,
        docName: request.docName,
        byteCount: 0,
        status: PrintJobStatus.error,
        errorMessage: 'Base64 inválido: $e',
      );
      _addJob(job);

      response.statusCode = HttpStatus.badRequest;
      response.write(jsonEncode({'sucesso': false, 'erro': 'Erro ao decodificar Base64: $e'}));
      await response.close();
      return;
    }

    try {
      await WindowsRawPrinter.printRawBytes(printerName, bytes, docName: request.docName);

      final job = PrintJob(
        id: jobId,
        timestamp: DateTime.now(),
        printerName: printerName,
        docName: request.docName,
        byteCount: bytes.length,
        status: PrintJobStatus.success,
        bytes: bytes,
      );
      _addJob(job);

      response.statusCode = HttpStatus.ok;
      response.write(jsonEncode({
        'sucesso': true,
        'mensagem': 'Enviado para a impressora $printerName com sucesso',
        'bytes': bytes.length,
        'impressora': printerName,
        'aviso': ?aviso,
      }));
      await response.close();
    } catch (e) {
      final job = PrintJob(
        id: jobId,
        timestamp: DateTime.now(),
        printerName: printerName,
        docName: request.docName,
        byteCount: bytes.length,
        status: PrintJobStatus.error,
        errorMessage: e.toString(),
        bytes: bytes,
      );
      _addJob(job);

      response.statusCode = HttpStatus.internalServerError;
      response.write(jsonEncode({'sucesso': false, 'erro': 'Falha na impressão: $e'}));
      await response.close();
    }
  }

  /// Trata conexões WebSocket (alternativa bi-direcional em tempo real)
  Future<void> _handleWebSocket(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    debugPrint('Cliente WebSocket conectado ao DRSystema Print');

    socket.listen((data) async {
      try {
        final parsed = jsonDecode(data.toString());
        final action = parsed['action']?.toString() ?? 'status';

        if (action == 'printers') {
          final printers = await WindowsRawPrinter.getPrinters();
          socket.add(jsonEncode({
            'action': 'printers',
            'sucesso': true,
            'impressoras': printers,
            'padrao': settingsService.selectedPrinter,
          }));
        } else if (action == 'print') {
          final printReq = PrintRequest.fromJson(parsed, defaultPrinter: settingsService.selectedPrinter);
          final (printer, aviso) = await _resolvePrinter(printReq.printer);

          if (printer == null) {
            socket.add(jsonEncode({'action': 'print', 'sucesso': false, 'erro': 'Nenhuma impressora configurada'}));
            return;
          }

          final bytes = printReq.toBytes();
          await WindowsRawPrinter.printRawBytes(printer, bytes, docName: printReq.docName);

          final job = PrintJob(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            timestamp: DateTime.now(),
            printerName: printer,
            docName: printReq.docName,
            byteCount: bytes.length,
            status: PrintJobStatus.success,
            bytes: bytes,
          );
          _addJob(job);

          socket.add(jsonEncode({
            'action': 'print',
            'sucesso': true,
            'impressora': printer,
            'bytes': bytes.length,
            'aviso': ?aviso,
          }));
        } else {
          socket.add(jsonEncode({
            'action': 'status',
            'sucesso': true,
            'online': true,
            'app': 'DRSystema Print',
            'impressora_padrao': settingsService.selectedPrinter,
          }));
        }
      } catch (e) {
        socket.add(jsonEncode({'sucesso': false, 'erro': e.toString()}));
      }
    });
  }

  /// Endpoint do validador oficial: recebe a senha do dia e devolve a
  /// URL real da API de conversão já com token embutido. Não contém
  /// nenhum segredo — sem a senha correta, ele só responde erro.
  static const _apiAuthUrl =
      'https://drsystema.com.br/themes/drsystema/biblioteca/print/auth_print.php';

  /// Troca a senha do dia (DR+DDMMAAAA) pela URL completa da API de
  /// conversão, consultando o validador remoto. Retorna null em caso de
  /// sucesso ou a mensagem de erro.
  Future<String?> exchangeApiSenha(String senha) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.postUrl(Uri.parse(_apiAuthUrl));
      req.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      req.write('senha=${Uri.encodeComponent(senha.trim())}');
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final body = await utf8.decoder.bind(resp).join();
      client.close(force: true);

      final json = jsonDecode(body);
      if (json is Map && json['sucesso'] == true && json['url'] is String) {
        await settingsService.setApiUrlXml(json['url']);
        await settingsService.setApiSenhaPendente('');
        return null;
      }
      return (json is Map && json['erro'] != null)
          ? json['erro'].toString()
          : 'Resposta inesperada do validador';
    } catch (e) {
      return 'Falha ao validar senha: $e';
    }
  }

  /// Verifica se o endpoint PHP de conversão XML (DanfcePos) está
  /// acessível — o app só oferece "Imprimir XML" se a API responder.
  /// Se a URL ainda não existe mas há uma senha pendente (instalador),
  /// tenta trocá-la pela URL antes de pingar.
  Future<bool> checkXmlApi() async {
    var url = settingsService.apiUrlXml.trim();
    if (url.isEmpty) {
      final senha = settingsService.apiSenhaPendente;
      if (senha != null && senha.isNotEmpty) {
        await exchangeApiSenha(senha);
        url = settingsService.apiUrlXml.trim();
      }
      if (url.isEmpty) return false;
    }
    try {
      final sep = url.contains('?') ? '&' : '?';
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(Uri.parse('$url${sep}ping=1'));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      final body = await utf8.decoder.bind(resp).join();
      client.close(force: true);
      return body.contains('"sucesso"') && body.contains('imprimir_xml');
    } catch (_) {
      return false;
    }
  }

  /// Envia um arquivo XML local para a API web, recebe o Base64 ESC/POS
  /// e imprime na impressora selecionada. Retorna null em caso de sucesso
  /// ou a mensagem de erro.
  Future<String?> printXmlFile(String filePath) async {
    final url = settingsService.apiUrlXml.trim();
    if (url.isEmpty) return 'URL da API de conversão não configurada';
    final printer = settingsService.selectedPrinter;
    if (printer == null || printer.isEmpty) return 'Nenhuma impressora selecionada';

    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    final docName = 'XML $fileName';
    final jobId = DateTime.now().millisecondsSinceEpoch.toString();

    String base64Text;
    try {
      final xmlBytes = await File(filePath).readAsBytes();
      final boundary = '----DRSystemaPrint${DateTime.now().millisecondsSinceEpoch}';
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(url));
      req.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');
      final body = <int>[
        ...utf8.encode('--$boundary\r\nContent-Disposition: form-data; '
            'name="xmlfile"; filename="$fileName"\r\n'
            'Content-Type: application/xml\r\n\r\n'),
        ...xmlBytes,
        ...utf8.encode('\r\n--$boundary--\r\n'),
      ];
      req.contentLength = body.length;
      req.add(body);
      final resp = await req.close().timeout(const Duration(seconds: 30));
      base64Text = (await utf8.decoder.bind(resp).join()).trim();
      client.close(force: true);
    } catch (e) {
      return 'Falha ao chamar a API: $e';
    }

    if (base64Text.contains('IMPRESSAO_ERRO') || base64Text.startsWith('Erro:')) {
      return base64Text;
    }
    if (base64Text.isEmpty) return 'A API retornou resposta vazia';

    try {
      final bytes = base64Decode(base64Text.replaceAll(RegExp(r'\s+'), ''));
      await WindowsRawPrinter.printRawBytes(printer, bytes, docName: docName);
      _addJob(PrintJob(
        id: jobId,
        timestamp: DateTime.now(),
        printerName: printer,
        docName: docName,
        byteCount: bytes.length,
        status: PrintJobStatus.success,
        bytes: bytes,
      ));
      return null;
    } catch (e) {
      _addJob(PrintJob(
        id: jobId,
        timestamp: DateTime.now(),
        printerName: printer,
        docName: docName,
        byteCount: 0,
        status: PrintJobStatus.error,
        errorMessage: e.toString(),
      ));
      return 'Falha na impressão: $e';
    }
  }

  /// Reenvia os bytes de um trabalho do histórico para a MESMA impressora
  /// em que foi impresso originalmente. Registra um novo job no histórico.
  Future<bool> reprintJob(PrintJob original) async {
    final data = original.bytes;
    if (data == null || data.isEmpty) return false;

    final docName = '${original.docName} (reimpressão)';
    final jobId = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      await WindowsRawPrinter.printRawBytes(original.printerName, data, docName: docName);
      _addJob(PrintJob(
        id: jobId,
        timestamp: DateTime.now(),
        printerName: original.printerName,
        docName: docName,
        byteCount: data.length,
        status: PrintJobStatus.success,
        bytes: data,
      ));
      return true;
    } catch (e) {
      _addJob(PrintJob(
        id: jobId,
        timestamp: DateTime.now(),
        printerName: original.printerName,
        docName: docName,
        byteCount: data.length,
        status: PrintJobStatus.error,
        errorMessage: e.toString(),
        bytes: data,
      ));
      return false;
    }
  }

  void _addJob(PrintJob job) {
    _history.insert(0, job);
    if (_history.length > 50) {
      _history.removeLast();
    }
    _historyController.add(List.unmodifiable(_history));
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    _historyController.add([]);
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _historyController.close();
    super.dispose();
  }
}
