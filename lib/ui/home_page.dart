import 'package:flutter/material.dart';
import '../models/print_job.dart';
import '../services/local_server.dart';
import '../services/settings_service.dart';
import '../services/windows_raw_printer.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  final LocalServer server;
  final SettingsService settings;

  const HomePage({
    super.key,
    required this.server,
    required this.settings,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> _printers = [];
  bool _loadingPrinters = false;
  bool _printingTest = false;
  final TextEditingController _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _portController.text = widget.settings.port.toString();
    _loadPrinters();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadPrinters() async {
    setState(() => _loadingPrinters = true);
    try {
      final list = await WindowsRawPrinter.getPrinters();
      setState(() {
        _printers = list;
        // Se a impressora gravada não estiver na lista ou estiver vazia, seleciona a primeira
        if (widget.settings.selectedPrinter == null ||
            !_printers.contains(widget.settings.selectedPrinter)) {
          if (_printers.isNotEmpty) {
            // Se encontrar 'Elgin' ou 'I8' na lista, prioriza
            final elgin = _printers.firstWhere(
              (p) => p.toLowerCase().contains('elgin') || p.toLowerCase().contains('i8'),
              orElse: () => _printers.first,
            );
            widget.settings.setSelectedPrinter(elgin);
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar impressoras: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  Future<void> _handleTestPrint() async {
    final printer = widget.settings.selectedPrinter;
    if (printer == null || printer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.warningColor,
          content: Text('Selecione uma impressora antes de imprimir o teste.'),
        ),
      );
      return;
    }

    setState(() => _printingTest = true);
    try {
      final bytes = WindowsRawPrinter.generateTestEscPosTicket(printer);
      await WindowsRawPrinter.printRawBytes(printer, bytes, docName: 'Teste DRSystema Print');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.successColor,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Cupom de teste enviado para "$printer" com sucesso!')),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.errorColor,
            content: Text('Erro ao imprimir teste: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.print_rounded, color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('DRSystema Print', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Ponte de Impressão Direta ESC/POS (NFC-e / Cupom)',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          _buildServerStatusBadge(),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Painel Esquerdo: Configurações e Seleção de Impressora
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPrinterCard(),
                  const SizedBox(height: 16),
                  _buildSettingsCard(),
                ],
              ),
            ),
          ),

          // Divisor vertical
          Container(width: 1, color: Colors.grey.withValues(alpha: 0.2)),

          // Painel Direito: Histórico em Tempo Real de Impressões
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildLogCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerStatusBadge() {
    return ListenableBuilder(
      listenable: widget.server,
      builder: (context, _) {
        final isRunning = widget.server.isRunning;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isRunning
                ? AppTheme.successColor.withValues(alpha: 0.12)
                : AppTheme.errorColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRunning ? AppTheme.successColor : AppTheme.errorColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRunning ? AppTheme.successColor : AppTheme.errorColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isRunning ? 'Servidor Ativo :${widget.settings.port}' : 'Servidor Inativo',
                style: TextStyle(
                  color: isRunning ? AppTheme.successColor : AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrinterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Text(
                      'Impressora Térmica (80mm)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Atualizar impressoras instaladas',
                  icon: _loadingPrinters
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _loadingPrinters ? null : _loadPrinters,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Selecione a impressora do Windows onde serão emitidos os cupons NFC-e e pedidos:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),

            // Dropdown de seleção de impressoras (como na imagem de referência)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade50,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _printers.contains(widget.settings.selectedPrinter)
                      ? widget.settings.selectedPrinter
                      : null,
                  hint: const Text('Selecione uma impressora...'),
                  items: _printers.map((name) {
                    final isElgin = name.toLowerCase().contains('elgin') || name.toLowerCase().contains('i8');
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Row(
                        children: [
                          Icon(
                            isElgin ? Icons.receipt_rounded : Icons.print_outlined,
                            size: 18,
                            color: isElgin ? AppTheme.primaryColor : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isElgin ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isElgin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Térmica', style: TextStyle(fontSize: 10, color: AppTheme.primaryColor)),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      widget.settings.setSelectedPrinter(val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botão de Impressão de Teste
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                icon: _printingTest
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.print, size: 18),
                label: const Text('Imprimir Cupom de Teste (Corte + ESC/POS)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _printingTest ? null : _handleTestPrint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.tune_rounded, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text('Preferências do Sistema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),

            // Iniciar com o Windows
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Iniciar com o Windows', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Executa o DRSystema Print em segundo plano ao ligar o PC', style: TextStyle(fontSize: 12)),
              value: widget.settings.autostart,
              activeThumbColor: AppTheme.primaryColor,
              onChanged: (val) => widget.settings.setAutostart(val),
            ),

            const Divider(height: 16),

            // Minimizar para a bandeja ao fechar
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Minimizar para a bandeja ao fechar', style: TextStyle(fontSize: 14)),
              subtitle: const Text('O botão [X] oculta a janela próximo ao relógio sem parar o serviço', style: TextStyle(fontSize: 12)),
              value: widget.settings.minimizeToTray,
              activeThumbColor: AppTheme.primaryColor,
              onChanged: (val) => widget.settings.setMinimizeToTray(val),
            ),

            const Divider(height: 16),

            // Porta do Servidor
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Porta do Servidor Local', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Text('Padrão: 8182 (Compatível com navegador e QZ)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 90,
                  height: 38,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onSubmitted: (val) async {
                      final p = int.tryParse(val);
                      if (p != null && p > 1024 && p < 65535) {
                        await widget.settings.setPort(p);
                        await widget.server.restart();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildLogCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.history_rounded, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Text('Histórico de Impressões', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Limpar', style: TextStyle(fontSize: 12)),
                  onPressed: widget.server.clearHistory,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Trabalhos recebidos do DRSystema Web via HTTP/WebSocket:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.server,
                builder: (context, _) {
                  final jobs = widget.server.history;
                  if (jobs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.print_disabled_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum trabalho de impressão recebido ainda.\nAo emitir uma NFC-e no PDV, ela aparecerá aqui.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: jobs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      final isSuccess = job.status == PrintJobStatus.success;

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isSuccess
                              ? AppTheme.successColor.withValues(alpha: 0.12)
                              : AppTheme.errorColor.withValues(alpha: 0.12),
                          child: Icon(
                            isSuccess ? Icons.check : Icons.error_outline,
                            size: 16,
                            color: isSuccess ? AppTheme.successColor : AppTheme.errorColor,
                          ),
                        ),
                        title: Text(
                          job.docName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${job.printerName} • ${job.formattedSize} • ${job.formattedTime}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSuccess
                                ? AppTheme.successColor.withValues(alpha: 0.1)
                                : AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isSuccess ? 'Sucesso' : 'Erro',
                            style: TextStyle(
                              color: isSuccess ? AppTheme.successColor : AppTheme.errorColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
