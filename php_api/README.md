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
3. **Defina seu token**: abra `imprimir_xml.php` e troque
   `PRINT_API_TOKEN` por um segredo gerado por você:
   ```bash
   openssl rand -hex 24
   ```
4. Teste no navegador (com seu token):
   ```
   https://seudominio.com.br/php_api/imprimir_xml.php?token=SEU_TOKEN&ping=1
   ```
   Deve responder `{"sucesso":true,"api":"imprimir_xml","versao":"1.0"}`
5. No app desktop: **Preferências → API de conversão XML** → cole a URL
   **com o token**: `.../imprimir_xml.php?token=SEU_TOKEN` → **Verificar**
   → o botão *"Imprimir arquivo XML"* habilita. O instalador também
   pergunta isso na opção "Minha própria API".

## Contrato da API

| Chamada | Resposta |
|---|---|
| `GET ?token=SEU_TOKEN&ping=1` | `{"sucesso":true,...}` — verificação do app |
| `POST ?token=SEU_TOKEN` + `xmlfile=<arquivo .xml>` | string Base64 com os bytes ESC/POS |
| `POST ?token=SEU_TOKEN` + `xml=<conteúdo xml>` | idem |
| Sem `token` ou token errado | HTTP 403 + `Erro: token de acesso inválido ou ausente` |
| XML inválido / erro | texto começando com `Erro:` ou `IMPRESSAO_ERRO:` |

> **Token permanente**: o token só muda se você alterar no arquivo —
> uma URL configurada continua válida até você revogar. Se quiser
> bloquear todos os apps de uma vez, basta trocar o token no servidor.

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
