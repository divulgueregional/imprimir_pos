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
3. Teste no navegador:
   ```
   https://seudominio.com.br/php_api/imprimir_xml.php?ping=1
   ```
   Deve responder `{"sucesso":true,"api":"imprimir_xml","versao":"1.0"}`
4. No app desktop: **Preferências → API de conversão XML** → cole a URL do
   passo 3 (sem o `?ping=1`) → **Verificar** → o botão *"Imprimir arquivo
   XML"* habilita.

## Contrato da API

| Chamada | Resposta |
|---|---|
| `GET ?ping=1` | `{"sucesso":true,...}` — verificação do app |
| `POST xmlfile=<arquivo .xml>` | string Base64 com os bytes ESC/POS |
| `POST xml=<conteúdo xml>` | idem |
| XML inválido / erro | texto começando com `Erro:` ou `IMPRESSAO_ERRO:` |

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
