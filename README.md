# 🖨️ DRSystema Print

Aplicativo Desktop em **Flutter** para Windows que funciona como uma **ponte de impressão local** do **DRSystema**.

Ele roda em segundo plano na bandeja do sistema e expõe um serviço HTTP/WebSocket em `127.0.0.1:8182`, permitindo que o sistema web (PHP + JavaScript no navegador) envie impressões térmicas de cupons fiscais (**NFC-e modelo 65**) e **NF-e (modelo 55)** diretamente para impressoras térmicas 80mm instaladas no Windows (ex: **Elgin I8**, Elgin I9, Epson TM-T20, Bematech MP-4200, Daruma) — sem abrir a janela de impressão do navegador.

> Foi projetado como substituto nativo para pontes de impressão baseadas em Java, ocupando a mesma porta e oferecendo integração compatível com o fluxo existente do PDV.

---

## 🚀 Vantagens em usar o DRSystema Print

| Recurso | DRSystema Print |
| :--- | :--- |
| **Tecnologia** | Nativo Windows C++ / Dart (~35MB de RAM), sem Java |
| **Instalação** | Executável autônomo, sem pré-requisitos |
| **Burocracia** | **Zero:** impressão silenciosa e direta, sem certificados ou assinatura de mensagens |
| **Custo** | **100% gratuito e de sua propriedade** |
| **Identidade Visual** | **100% DRSystema** — cores, ícone e bandeja |
| **Velocidade** | **< 50ms** — comunicação direta com o Win32 Spooler |
| **Segundo plano** | Inicia com o Windows já na bandeja; fechar a janela não interrompe o serviço |

---

## 📁 Estrutura do Projeto

```
imprimir_pos/
├── lib/
│   ├── main.dart                      # Inicialização, DI e ciclo de vida
│   ├── models/
│   │   ├── print_job.dart             # Modelo do histórico de trabalhos impressos
│   │   └── print_request.dart         # Parser de payload (Base64 -> Bytes ESC/POS)
│   ├── services/
│   │   ├── windows_raw_printer.dart   # Comunicação Win32 FFI com winspool.drv (Modo RAW)
│   │   ├── windows_window.dart        # Controle nativo da janela (FindWindow/ShowWindow/SetProp)
│   │   ├── local_server.dart          # Servidor HTTP/WebSocket (127.0.0.1:8182) com CORS/PNA
│   │   ├── tray_service.dart          # Gerenciamento da Bandeja do Sistema (System Tray)
│   │   └── settings_service.dart      # Persistência da impressora padrão e preferências
│   └── ui/
│       ├── home_page.dart             # Painel com dropdown de impressoras e botão de teste
│       └── theme.dart                 # Identidade visual DRSystema (Material 3)
├── web_client/
│   └── drsystema_print_client.js      # Biblioteca JS drop-in para integração no PHP
├── installer/
│   └── drsystema_print_installer.iss  # Script Inno Setup para gerar DRSystemaPrintSetup.exe
└── windows/                           # Projeto C++ nativo do Windows Runner
```

---

## 🛠️ Como Funciona a Comunicação

1. O backend PHP (`imprimir.php` ou `cupom.php`) processa a NFC-e via `NFePHP\POS\DanfcePos` e gera os bytes binários ESC/POS (tabelas, alinhamento, QR Code, corte de papel).
2. O conector PHP retorna esses bytes codificados em **Base64**.
3. O JavaScript do PDV (`drsystema_print_client.js`) faz um `POST http://127.0.0.1:8182/print` contendo a string Base64.
4. O **DRSystema Print** decodifica o Base64 para array de bytes nativo (`Uint8List`).
5. Chama a API do Windows Spooler (`winspool.drv`):
   - `OpenPrinterW("Elgin I8")`
   - `StartDocPrinterW(..., "RAW")`
   - `WritePrinter(bytes)`
   - `EndDocPrinter()` / `ClosePrinter()`
6. A Elgin I8 imprime o cupom instantaneamente e corta o papel!

---

## 🌐 Endpoints da API Local (Porta 8182)

O aplicativo disponibiliza uma API local com suporte a **CORS** e cabeçalhos de **Private Network Access (PNA)**:

### 1. `GET /status`
Retorna o estado do serviço e a impressora selecionada.
```json
{
  "sucesso": true,
  "status": "online",
  "app": "DRSystema Print",
  "versao": "1.0.0",
  "porta": 8182,
  "impressora_padrao": "Elgin I8"
}
```

### 2. `GET /printers`
Retorna todas as impressoras instaladas no Windows.
```json
{
  "sucesso": true,
  "impressoras": [
    "Elgin I8",
    "EPSON TM-T20",
    "Microsoft Print to PDF"
  ],
  "padrao": "Elgin I8"
}
```

### 3. `POST /print`
Recebe o conteúdo da nota para impressão imediata.
```json
{
  "printer": "Elgin I8",
  "data": "G0BA...STRING_BASE64_DOS_BYTES_ESCPOS...",
  "type": "raw",
  "docName": "DRSystema Cupom NFC-e"
}
```

*Nota:* O endpoint também aceita diretamente o formato legado em array de objetos:
```json
[
  {
    "type": "raw",
    "format": "base64",
    "data": "G0BA...STRING_BASE64_DOS_BYTES_ESCPOS..."
  }
]
```

---

## 💻 Como Compilar e Gerar o Executável para Windows

Em qualquer máquina Windows com o Flutter instalado:

```powershell
# 1. Obter dependências
flutter pub get

# 2. Compilar em modo Release para Windows
flutter build windows --release
```

Os arquivos compilados estarão em:
`build\windows\x64\runner\Release\`

Para gerar o instalador `DRSystemaPrintSetup.exe`:
1. Abra o arquivo `installer\drsystema_print_installer.iss` no **Inno Setup Compiler**.
2. Clique em **Build** (F9).
3. O instalador final estará pronto na pasta `installer_output\DRSystemaPrintSetup.exe`.

Também é possível compilar direto no GitHub: todo push para `main` dispara o workflow
**"Compilar DRSystema Print (Windows)"** e gera o artifact `drsystema-print-windows`
na página do run, em *Actions*.

---

## 🧩 Integração com o DRSystema (Web)

Basta incluir no seu tema PHP o arquivo [drsystema_print_client.js](web_client/drsystema_print_client.js):

```html
<script src="<?= INCLUDE_PATH ?>/biblioteca/print/drsystema_print_client.js"></script>
```

Ele já define `window.JSPrint = DRSystemaPrint`, garantindo compatibilidade imediata com as funções existentes no seu `pdv.php`:
- `imprimir_drsystema(fatura_id)`
- `imprimir_cupom(fatura_id)`
- `imprimir_nfe(fatura_id)`
- `selecionarImpressoraQZ()`
