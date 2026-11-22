<?php

use NFePHP\POS\DanfcePos;
use NFePHP\NFe\Common\Standardize;
use Mike42\Escpos\Printer;

class DanfeSimplificadoPos extends DanfcePos
{
    protected $std;
    protected $myConnector;
    protected $chave = '';

    public function __construct($connector, string $chave = '')
    {
        $this->myConnector = $connector;
        $this->chave = preg_replace('/\D/', '', $chave);
        parent::__construct($connector);
    }

    public function loadNFe(string $xml): void
    {
        if (is_file($xml)) {
            $xml = file_get_contents($xml);
        }
        $st = new Standardize();
        $this->std = $st->toStd($xml);
        $this->printer = new Printer($this->myConnector);
    }

    private function imprimirCodigo(string $tipo, string $conteudo, int $altura, int $modulo = 1): void
    {
        $barcode = new \Com\Tecnick\Barcode\Barcode();
        $bobj = $barcode->getBarcodeObj($tipo, $conteudo, -$modulo, -$altura, 'black', array(0, -2, 0, -2))->setBackgroundColor('white');
        $tmp = tempnam(sys_get_temp_dir(), 'danfe55_');
        file_put_contents($tmp, $bobj->getPngData());
        if (method_exists($this->printer, 'image')) {
            $this->printer->image($tmp, 0, $altura, Printer::IMG_DEFAULT);
        } else {
            $img = \Mike42\Escpos\EscposImage::load($tmp);
            if (method_exists($this->printer, 'graphics')) {
                $this->printer->graphics($img, 0, 0, $img->getWidth(), $img->getHeight(), Printer::IMG_DEFAULT);
            } elseif (method_exists($this->printer, 'bitImage')) {
                $this->printer->bitImage($img, 0, 0, $img->getWidth(), $img->getHeight(), Printer::IMG_DEFAULT);
            }
        }
        unlink($tmp);
    }

    private function imprimirQrCodeNativo(string $url, int $size = 4): void
    {
        $len = strlen($url) + 3;
        $pL = chr($len % 256) . chr(intdiv($len, 256));
        $this->myConnector->write("\x1D\x28\x6B\x04\x00\x31\x41\x32\x00");
        $this->myConnector->write("\x1D\x28\x6B\x03\x00\x31\x43" . chr($size));
        $this->myConnector->write("\x1D\x28\x6B\x03\x00\x31\x45\x31");
        $this->myConnector->write("\x1D\x28\x6B" . $pL . "\x31\x50\x30" . $url);
        $this->myConnector->write("\x1D\x28\x6B\x03\x00\x31\x51\x30");
    }

    private function qrCodeUrl(): string
    {
        return 'https://www.nfe.fazenda.gov.br/portal/consultaRecaptcha.aspx?tipoConsulta=resumo&tipoConteudo=7PhJ+gAVw2g=&nfe=' . $this->chave;
    }
    public function imprimir(): void
    {
        $nfe = $this->std->NFe->infNFe;
        $prot = $this->std->protNFe->infProt ?? null;
        $ide = $nfe->ide;
        $emit = $nfe->emit;
        $dest = $nfe->dest ?? null;
        $total = $nfe->total->ICMSTot;
        $infAdic = $nfe->infAdic ?? null;
        $chave = preg_replace('/\D/', '', (string) ($ide->chave ?: $nfe->Id ?: $this->chave ?: ''));
        $this->chave = $chave;
        $nProt = $prot->nProt ?? '';

        $this->printer->setJustification(Printer::JUSTIFY_CENTER);
        $this->printer->setEmphasis(true);
        $this->printer->text("DANFE SIMPLIFICADA - NF-e\n");
        $this->printer->setEmphasis(false);
        $this->printer->text($emit->xNome . "\n");
        $this->printer->text("CNPJ: " . ($emit->CNPJ ?? '') . "  IE: " . ($emit->IE ?? '') . "\n");
        $ee = $emit->enderEmit ?? null;
        if ($ee) {
            $this->printer->text(($ee->xLgr ?? '') . ', ' . ($ee->nro ?? '') . " - " . ($ee->xBairro ?? '') . "\n");
            $this->printer->text(($ee->xMun ?? '') . '/' . ($ee->UF ?? '') . " - CEP " . ($ee->CEP ?? '') . "\n");
        }
        $this->printer->text(str_repeat('-', 48) . "\n");
        $this->printer->text($chave . "\n");
        $this->imprimirCodigo('C128', $chave, 50, 1);
        $this->printer->text("Protocolo: " . $nProt . "\n");
        $this->printer->text("Nº " . ($ide->nNF ?? '') . " Série " . ($ide->serie ?? '') . "\n");
        $this->printer->text("Emissão: " . ($ide->dhEmi ?? '') . "\n");
        $this->imprimirQrCodeNativo($this->qrCodeUrl(), 4);
        $this->printer->text(str_repeat('-', 48) . "\n");

        if (($ide->tpEmis ?? '') == 9) {
            $this->printer->text("EMITIDA EM CONTINGENCIA OFFLINE\n");
            $this->printer->text("Via do Estabelecimento\n");
        }

        $this->printer->setJustification(Printer::JUSTIFY_LEFT);
        $this->printer->text("DESTINATÁRIO\n");
        $this->printer->text(($dest->xNome ?? 'CONSUMIDOR') . "\n");
        $this->printer->text("CNPJ/CPF: " . ($dest->CNPJ ?? $dest->CPF ?? '') . "  IE: " . ($dest->IE ?? '') . "\n");
        $de = $dest->enderDest ?? null;
        if ($de) {
            $this->printer->text(($de->xLgr ?? '') . ', ' . ($de->nro ?? '') . " - " . ($de->xBairro ?? '') . "\n");
            $this->printer->text(($de->xMun ?? '') . '/' . ($de->UF ?? '') . " - CEP " . ($de->CEP ?? '') . "\n");
        }
        $this->printer->text(str_repeat('-', 48) . "\n");

        $this->printer->text("ITENS\n");
        $dets = is_array($nfe->det) ? $nfe->det : [$nfe->det];
        foreach ($dets as $det) {
            $prod = $det->prod;
            $this->printer->text($prod->xProd . "\n");
            $this->printer->text(number_format((float) ($prod->qCom ?? 0), 2, ',', '.') . " " . ($prod->uCom ?? '') . " x " . number_format((float) ($prod->vUnCom ?? 0), 2, ',', '.') . " = " . number_format((float) ($prod->vProd ?? 0), 2, ',', '.') . "\n");
            $ibs = $det->imposto->IBSCBS ?? null;
            if ($ibs) {
                $this->printer->text("IBS: " . ($ibs->vIBS ?? '') . "  CBS: " . ($ibs->vCBS ?? '') . "  IS: " . ($ibs->vIS ?? '') . "\n");
            }
        }

        $this->printer->text(str_repeat('-', 48) . "\n");
        $this->printer->text("Valor dos produtos: " . number_format((float) ($total->vProd ?? 0), 2, ',', '.') . "\n");
        $this->printer->text("Desconto: " . number_format((float) ($total->vDesc ?? 0), 2, ',', '.') . "\n");
        $this->printer->text("TOTAL: " . number_format((float) ($total->vNF ?? 0), 2, ',', '.') . "\n");
        $this->printer->text("Tributos aprox.: " . number_format((float) ($total->vTotTrib ?? 0), 2, ',', '.') . "\n");

        $transp = $nfe->transp ?? null;
        if ($transp) {
            $this->printer->text(str_repeat('-', 48) . "\n");
            $this->printer->text("TRANSPORTE\n");
            $this->printer->text("Frete: " . ($transp->modFrete ?? '') . "\n");
            $transpNome = $transp->transporta->xNome ?? '';
            if ($transpNome) {
                $this->printer->text("Transportadora: " . $transpNome . "\n");
            }
            $vol = $transp->vol ?? null;
            if ($vol) {
                $this->printer->text("Volumes: " . ($vol->qVol ?? '') . " " . ($vol->esp ?? '') . "\n");
                $this->printer->text("Peso L: " . ($vol->pesoL ?? '') . " Peso B: " . ($vol->pesoB ?? '') . "\n");
            }
        }

        $cobr = $nfe->cobr ?? null;
        if ($cobr) {
            $this->printer->text(str_repeat('-', 48) . "\n");
            $this->printer->text("COBRANÇA\n");
            if (!empty($cobr->fat)) {
                $this->printer->text("Fatura: " . ($cobr->fat->nFat ?? '') . " - " . ($cobr->fat->vLiq ?? '') . "\n");
            }
            $dups = $cobr->dup ?? null;
            if ($dups) {
                $dups = is_array($dups) ? $dups : [$dups];
                foreach ($dups as $dup) {
                    $this->printer->text("Dup " . ($dup->nDup ?? '') . " " . ($dup->dVenc ?? '') . " " . ($dup->vDup ?? '') . "\n");
                }
            }
        }

        $ibsTot = $total->IBSCBSTot ?? null;
        $isTot = $total->IS ?? null;
        if ($ibsTot || $isTot) {
            $this->printer->text(str_repeat('-', 48) . "\n");
            $this->printer->text("III-A - IBS/CBS/IS\n");
            if ($ibsTot) {
                $this->printer->text("IBS: " . ($ibsTot->vIBS ?? '') . "  CBS: " . ($ibsTot->vCBS ?? '') . "\n");
            }
            if ($isTot) {
                $this->printer->text("IS: " . ($isTot->vIS ?? '') . "\n");
            }
        }

        $this->printer->text(str_repeat('-', 48) . "\n");
        $this->printer->text("INFORMAÇÕES ADICIONAIS\n");
        $this->printer->text(($infAdic->infCpl ?? '') . "\n");
        $this->printer->text("DRSystema - drsystema.com.br\n");
        $this->printer->cut();
        $this->printer->close();
    }
}
