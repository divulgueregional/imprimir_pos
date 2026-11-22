# php_api — API de conversão XML → ESC/POS

Pasta **portátil** da API web que o app desktop usa para imprimir XML fiscal
(NFC-e 65 / NF-e 55). Independe do DRSystema: pode ser instalada em qualquer
domínio/servidor PHP.

## Conteúdo

| Arquivo | Função |
|---|---|
| `imprimir_xml.php` | Endpoint HTTP: ping (`?ping=1`) e conversão XML → Base64 |
| `DanfeSimplificadoPos.php` | Layout de impressão da NF-e modelo 55 (DANFE simplificado POS) |
| `sped_pos_patch/Base64PrintConnector.php` | Conector que captura os bytes ESC/POS em Base64 em vez de imprimir |
| `composer.json` | Dependências: `nfephp-org/sped-pos`, `sped-nfe`, `mike42/escpos-php`, barcode |

## Instalação em outro domínio

1. Copie esta pasta `php_api/` para um diretório público do servidor
   (ex.: `https://seudominio.com.br/php_api/`)
2. No servidor, dentro da pasta, instale as dependências:
   ```bash
   composer install
   ```
   (requer PHP >= 8.0 com extensão `gd` habilitada — usada para gerar o
   código de barras da chave de acesso na NF-e 55)
3. **Defina sua chave**: abra `imprimir_xml.php` e troque
   `PRINT_API_PREFIX` por um segredo seu. A chave válida do dia é
   `PREFIXO + DDMMAAAA` — ex.: com prefixo `ACME`, em 05/03/2025 a senha
   é `ACME05032025`.
4. Teste no navegador (com a chave do dia):
   ```
   https://seudominio.com.br/php_api/imprimir_xml.php?key=ACME05032025&ping=1
   ```
   Deve responder `{"sucesso":true,"api":"imprimir_xml","versao":"1.0"}`
5. No app desktop: **Preferências → API de conversão XML** → cole a URL
   **com a chave**: `.../imprimir_xml.php?key=ACME05032025` → **Verificar**
   → o botão *"Imprimir arquivo XML"* habilita. O instalador também
   pergunta isso na opção "Minha própria API".

## Contrato da API

| Chamada | Resposta |
|---|---|
| `GET ?key=CHAVE&ping=1` | `{"sucesso":true,...}` — verificação do app |
| `POST ?key=CHAVE` + `xmlfile=<arquivo .xml>` | string Base64 com os bytes ESC/POS |
| `POST ?key=CHAVE` + `xml=<conteúdo xml>` | idem |
| Sem `key` ou chave errada | HTTP 403 + `Erro: chave de acesso inválida ou ausente` |
| XML inválido / erro | texto começando com `Erro:` ou `IMPRESSAO_ERRO:` |

> **Chave diária**: a chave muda todo dia (`PREFIXO + data`). Isso é
> proteção casual — suficiente para impedir que estranhos usem seu
> endpoint achando a URL por acaso. Para algo mais forte, troque a
> verificação por um token fixo longo guardado só no servidor.

O app envia o XML, recebe o Base64 e imprime na impressora do Windows
selecionada. A conversão em si (layout, QR Code, itens, totais) é toda feita
aqui — o desktop é apenas transporte.

## Observações

- **NFC-e 65**: usa `NFePHP\POS\DanfcePos` direto do pacote sped-pos
- **NF-e 55**: usa `DanfeSimplificadoPos.php` (classe local, DANFE
  simplificado com chave em código de barras + QR Code de consulta)
- No DRSystema, a versão equivalente deste endpoint fica em
  `themes/drsystema/biblioteca/print/imprimir_xml.php` (mesma lógica, mas
  carrega o `Config.inc.php` da aplicação e usa os sped descompactados
  em vez do composer)
- ⚠️ Este endpoint é público — qualquer um que conheça a URL pode
  converter XML. Para produção, considere adicionar um token de acesso
  (`?token=...`) ou restringir por IP.
