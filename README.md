# 🖨️ DRSystema Print

[![Baixar Instalador](https://img.shields.io/badge/Download-DRSystemaPrintSetup.exe-1E3A8A?logo=windows)](https://github.com/divulgueregional/imprimir_pos/releases/latest/download/DRSystemaPrintSetup.exe)

Aplicativo Desktop em **Flutter** para Windows que funciona como uma **ponte de impressão local** do **DRSystema**.

Ele roda em segundo plano na bandeja do sistema e expõe um serviço HTTP/WebSocket em `127.0.0.1:8182`, permitindo que o sistema web (PHP + JavaScript no navegador) envie impressões térmicas de cupons fiscais (**NFC-e modelo 65**) e **NF-e (modelo 55)** diretamente para impressoras térmicas 80mm instaladas no Windows (ex: **Elgin I8**, Elgin I9, Epson TM-T20, Bematech MP-4200, Daruma) — sem abrir a janela de impressão do navegador.

> Foi projetado como substituto nativo para pontes de impressão baseadas em Java, ocupando a mesma porta e oferecendo integração compatível com o fluxo existente do PDV.

---

## 🚀 Vantagens em usar o DRSystema Print

| Recurso | DRSystema Print |
| :--- | :--- |
| **Tecnologia** | Nativo Windows C++ / Dart (~35MB de RAM), sem Java |
| **Instalação** | Executável autônomo, sem pré-requisitos |
| **Burocracia** | **Zero:** impressão silenciosa e direta, sem certificados ou assinatura digital |
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
│   │   ├── windows_window.dart        # Helpers Win32 (FindWindow/ShowWindow/SetProp)
│   │   ├── local_server.dart          # Servidor HTTP/WebSocket (127.0.0.1:8182) com CORS/PNA
│   │   ├── tray_service.dart          # Gerenciamento da Bandeja do Sistema (System Tray)
│   │   └── settings_service.dart      # Persistência da impressora padrão e preferências
│   └── ui/
│       ├── home_page.dart             # Painel com dropdown de impressoras e botão de teste
│       └── theme.dart                 # Identidade visual DRSystema (Material 3)
├── web_client/
│   ├── drsystema_print_client.js      # Biblioteca JS drop-in para integração no PHP
│   └── teste_impressao.html           # Página standalone de teste (sem backend)
├── php_api/                           # API web portátil: converte XML fiscal → Base64 ESC/POS
│   ├── imprimir_xml.php               #   Endpoint usado pelo app p/ imprimir XML local
│   ├── DanfeSimplificadoPos.php       #   Layout NF-e 55 (DANFE simplificado POS)
│   ├── sped_pos_patch/                #   Conector Base64 (escpos-php 4.x/5.x)
│   └── composer.json                  #   Dependências PHP (sped-pos, escpos-php...)
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

## 📦 Dependência de conteúdo: quem gera os bytes

Este app **só transporta bytes prontos**. Ele não monta cupom, não lê XML e não entende layout — quem gera os comandos ESC/POS é uma biblioteca no **seu** sistema. No DRSystema, essa biblioteca é o pacote PHP [`nfephp-org/sped-pos`](https://github.com/nfephp-org/sped-pos) (classe `NFePHP\POS\DanfcePos`), que transforma o XML autorizado da NFC-e em comandos de impressora.

### Instalação (no projeto PHP)

```bash
composer require nfephp-org/sped-pos
composer require mike42/escpos-php   # exigida pelo DanfcePos (conector de impressão)
```

### Como o PHP usa (XML → Base64)

O `DanfcePos` precisa de um conector do `escpos-php`. Para capturar os bytes **sem imprimir**, usa-se o `DummyPrintConnector`, que grava tudo num buffer:

```php
use NFePHP\POS\DanfcePos;
use Mike42\Escpos\PrintConnectors\DummyPrintConnector;

$connector = new DummyPrintConnector();
$danfcepos = new DanfcePos($connector);
$danfcepos->loadNFCe($caminhoOuStringDoXml);  // XML da NFC-e autorizada
$danfcepos->imprimir();

$bytes = $connector->getData();   // ESC/POS puro
echo base64_encode($bytes);       // devolve ao navegador
```

### Como o JS envia ao app (Base64 → papel)

```js
fetch('http://127.0.0.1:8182/print', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    printer: 'Elgin I8',            // nome exato no Windows (opcional)
    data: '<base64 vindo do PHP>',
    type: 'raw',
    docName: 'Cupom NFC-e'
  })
})
```

> **Resumo da divisão:** o PHP transforma XML em bytes ESC/POS; este app transforma bytes em papel. Qualquer fonte de bytes ESC/POS em Base64 funciona — `mike42/escpos-php`, `python-escpos`, comandos montados à mão — o app não sabe nem precisa saber o que está sendo impresso.

### 🗂️ Imprimir XML direto do app (sem abrir o navegador)

O app desktop também consegue imprimir um **arquivo XML salvo na máquina** — a conversão para ESC/POS é feita por uma API web, e o app só transporta o resultado:

```
[App] seleciona .xml → POST para API web → Base64 de volta → imprime no Windows
```

O endpoint de referência é a pasta [`php_api/`](php_api/) deste repositório — **portátil**, funciona em qualquer domínio:

1. Copie `php_api/` para o servidor e rode `composer install` dentro dela
2. Teste `https://seudominio.com.br/php_api/imprimir_xml.php?ping=1` → responde `{"sucesso":true,...}`
3. No app: **Preferências → API de conversão XML** → cole a URL → **Verificar** (✓ verde)
4. O botão **"Imprimir arquivo XML"** só habilita com a API respondendo

Detalhes completos em [`php_api/README.md`](php_api/README.md). A URL fica salva no app e pode ser alterada a qualquer momento — útil se o arquivo mudar de lugar no servidor ou o cliente trocar de domínio.

### Teste sem backend

O arquivo [`web_client/teste_impressao.html`](web_client/teste_impressao.html) é uma página de homologação **standalone**: abra direto no navegador para checar a conexão, listar as impressoras do Windows e imprimir um cupom de teste ESC/POS — sem precisar de PHP nem do sistema completo.

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

> **Nota:** O endpoint também aceita diretamente o formato legado em array de objetos:
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

## 🖨️ Imprimindo em impressoras diferentes

O app tem **uma impressora padrão** — escolhida na janela do aplicativo. Toda requisição que **não informa impressora** sai nela.

Mas **cada impressão pode sair numa impressora diferente**: basta enviar o campo `printer` com o nome exato da impressora instalada no Windows — o mesmo nome que o `GET /printers` retorna (inclusive impressoras de rede). O `printer` vale **por requisição** e não muda a padrão.

### Na prática

```jsonc
// Cupom NFC-e → térmica do caixa
POST /print   { "printer": "Elgin I8", "data": "..." }

// DANFE NF-e → laser do escritório
POST /print   { "printer": "HP LaserJet", "data": "..." }

// Produção → impressora da cozinha (rede)
POST /print   { "printer": "Bematech Cozinha", "data": "..." }

// Sem "printer" → sai na impressora padrão
POST /print   { "data": "..." }
```

Na mesma página é possível disparar várias impressões seguidas para impressoras diferentes — por exemplo, fechar o cupom na térmica do caixa e, logo em seguida, enviar o pedido para a impressora da cozinha.

### No JavaScript

O `drsystema_print_client.js` envia a impressora selecionada no campo `printer` do `POST /print`. Para direcionar uma rotina específica a outra impressora, basta enviar outro nome nesse campo na chamada — por exemplo, ler o nome de uma configuração da tela e passar direto no `fetch`.

### Fallback de segurança

Se o nome enviado não existir no Windows, a impressão **cai automaticamente na impressora padrão** e a resposta JSON traz o campo `aviso` informando o redirecionamento — o cupom não se perde por divergência de nomes entre máquinas.

---

## 🖥️ Instalando no Windows (usuário final)

**Download direto (público, sem login no GitHub):**

👉 [Baixar DRSystemaPrintSetup.exe — última versão](https://github.com/divulgueregional/imprimir_pos/releases/latest/download/DRSystemaPrintSetup.exe)

O link acima sempre aponta para o instalador mais recente publicado pelo GitHub Actions. Ao executar o **`DRSystemaPrintSetup.exe`**:

- O assistente pergunta a **pasta de instalação** (padrão: `Program Files\DRSystema Print`)
- Cria atalho no Menu Iniciar (e opcionalmente na Área de Trabalho)
- Oferece a opção **"Iniciar automaticamente com o Windows"** (marcada por padrão)
- Instalação por usuário — **não exige administrador**

Ao final da instalação o app já inicia: **um ícone de impressora aparece na bandeja do Windows** (área de notificação, perto do relógio — pode ficar dentro da setinha `^`). O app é um serviço de segundo plano: a janela **não abre sozinha**.

- **Clique no ícone** → abre a janela do app (status do servidor, impressora padrão, histórico)
- **Clique direito no ícone** → menu: *Abrir*, *Imprimir Cupom de Teste*, *Encerrar Aplicativo*
- **Fechar a janela no [X]** → esconde de volta para a bandeja; o serviço continua ativo e imprimindo
- **Encerrar de verdade** → só pelo menu *Encerrar Aplicativo* da bandeja

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
