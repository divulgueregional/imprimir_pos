<?php
// imprimir_xml.php — API de conversão XML → ESC/POS (Base64) para o DRSystema Print.
//
// Versão PORTÁTIL (independe do DRSystema): basta copiar esta pasta para o
// servidor, rodar `composer install` e apontar a URL no app desktop.
//
// Endpoints:
//   GET  ?ping=1            → {"sucesso":true,...}  (verificação do app)
//   POST xmlfile=<arquivo>  → Base64 ESC/POS        (upload multipart)
//   POST xml=<conteúdo>     → Base64 ESC/POS        (XML colado)

// Ping leve: responde sem carregar nada pesado
if (isset($_GET['ping'])) {
    header('Content-Type: application/json');
    echo json_encode(['sucesso' => true, 'api' => 'imprimir_xml', 'versao' => '1.0']);
    exit;
}

error_reporting(E_ALL & ~E_DEPRECATED);
ini_set('display_errors', 0);

// 1. Receber o XML: arquivo enviado OU conteúdo colado
$xmlContent = null;
if (!empty($_FILES['xmlfile']) && $_FILES['xmlfile']['error'] === UPLOAD_ERR_OK) {
    $xmlContent = file_get_contents($_FILES['xmlfile']['tmp_name']);
} elseif (!empty($_POST['xml'])) {
    $xmlContent = $_POST['xml'];
}

if (!$xmlContent || trim($xmlContent) === '') {
    echo 'Erro: Nenhum XML enviado';
    exit;
}

// 2. Detectar o modelo fiscal (65 = NFC-e | 55 = NF-e)
$modelo = 0;
if (preg_match('/<mod>(\d+)<\/mod>/', $xmlContent, $m)) {
    $modelo = (int) $m[1];
}
if ($modelo !== 65 && $modelo !== 55) {
    echo 'Erro: XML sem <mod>55</mod> ou <mod>65</mod> reconhecível';
    exit;
}

// 3. Extrair a chave de acesso (Id="NFe{44 dígitos}")
$chave = '';
if (preg_match('/Id="NFe(\d{44})"/', $xmlContent, $m)) {
    $chave = $m[1];
}

require_once __DIR__ . '/vendor/autoload.php';
// Fix PHP 8.x / escpos-php 5.x: conector compatível com as duas versões
require_once __DIR__ . '/sped_pos_patch/Base64PrintConnector.php';
require_once __DIR__ . '/DanfeSimplificadoPos.php';

use NFePHP\POS\PrintConnectors\Base64PrintConnector;
use NFePHP\POS\DanfcePos;

try {
    // 4. Gravar temporário — as classes leem o XML de arquivo
    $tmpFile = sys_get_temp_dir() . '/nfce_' . ($chave ?: uniqid('xml_')) . '.xml';
    file_put_contents($tmpFile, $xmlContent);

    $connector = new Base64PrintConnector();

    if ($modelo == 55) {
        $danfe = new DanfeSimplificadoPos($connector, $chave);
        $danfe->loadNFe($tmpFile);
        $danfe->imprimir();
    } else {
        $danfcepos = new DanfcePos($connector);
        $danfcepos->loadNFCe($tmpFile);
        $danfcepos->imprimir();
    }

    echo $connector->getBase64Data();

    @unlink($tmpFile);
} catch (Throwable $e) {
    http_response_code(500);
    echo 'IMPRESSAO_ERRO: ' . $e->getMessage() . ' | ' . basename($e->getFile()) . ':' . $e->getLine();
    error_log('imprimir_xml.php ' . $e->getMessage() . ' @ ' . $e->getFile() . ':' . $e->getLine());
}
