<?php

namespace NFePHP\POS\PrintConnectors;

use Mike42\Escpos\PrintConnectors\PrintConnector;

/**
 * Conector que disponibiliza resultado como uma string base64.
 *
 * Versão compatível com escpos-php 4.x e 5.x (PHP 8.3):
 * a interface PrintConnector da v5 declara tipos de retorno,
 * então esta implementação declara os mesmos retornos e
 * mantém os parâmetros sem tipo (válido nas duas versões).
 */
class Base64PrintConnector implements PrintConnector
{
    /**
     * @var array $buffer
     *  Buffer of accumilated data.
     */
    private $buffer;

    /**
     * @var string data which the printer will provide on next read
     */
    private $readData = '';

    /**
     * Create new print connector
     */
    public function __construct()
    {
        $this->buffer = array();
    }

    /**
     * Destructor of print connector.
     * Does nothing in this print connector.
     */
    public function __destruct()
    {
    }

    /**
     * Clear buffer of print connector
     */
    public function clear()
    {
        $this->buffer = array();
    }

    /**
     * Does nothing in this print connector.
     * Normally closes the connection with printer.
     */
    public function finalize(): void
    {
    }

    /**
     * @return string Get the accumulated data that has been sent to this buffer.
     */
    public function getData()
    {
        return implode($this->buffer);
    }

    /**
     * @return string Get as base64 the accumulated data that has been sent to this buffer.
     */
    public function getBase64Data()
    {
        return base64_encode(implode($this->buffer));
    }

    /**
     * {@inheritDoc}
     * @see PrintConnector::read()
     */
    public function read($len): bool|string
    {
        return $len >= strlen($this->readData) ? $this->readData : substr($this->readData, 0, $len);
    }

    public function write($data): void
    {
        $this->buffer[] = $data;
    }
}
