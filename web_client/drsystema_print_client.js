/**
 * DRSystema Print Client (Substituto Direto do QZ Tray para DRSystema Web)
 * 
 * Comunicação direta com o aplicativo desktop DRSystema Print rodando na máquina Windows.
 * Funciona via HTTP REST e WebSocket em 127.0.0.1:8182 com suporte a CORS e PNA.
 */

class DRSystemaPrint {
    constructor(porta = 8182) {
        this.porta = porta;
        this.baseUrl = `http://127.0.0.1:${porta}`;
        this.wsUrl = `ws://127.0.0.1:${porta}`;
        this.conectado = false;
        this.nomeImpressora = localStorage.getItem('imp_qz_selecionada') || '';
        this.linkDownload = 'https://drsystema.com.br/download/DRSystemaPrintSetup.exe';
    }

    /**
     * Verifica se o aplicativo DRSystema Print está aberto na máquina local
     */
    async checarConexao() {
        try {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 2000);

            const resposta = await fetch(`${this.baseUrl}/status`, {
                method: 'GET',
                signal: controller.signal
            });

            clearTimeout(timeoutId);

            if (resposta.ok) {
                const dados = await resposta.json();
                this.conectado = true;
                if (!this.nomeImpressora && dados.impressora_padrao) {
                    this.nomeImpressora = dados.impressora_padrao;
                }
                return true;
            }
        } catch (e) {
            this.conectado = false;
        }
        return false;
    }

    // Compatibilidade com a chamada legada: imp.conectarQZ()
    conectarQZ() {
        const self = this;
        this.checarConexao().then(conectou => {
            if (conectou) {
                console.log('✅ DRSystema Print conectado na porta ' + self.porta);
            } else {
                console.warn('⚠️ DRSystema Print não está rodando no computador.');
            }
        });
    }

    setCertificado() {
        // No DRSystema Print NÃO é necessário nenhum certificado digital pago ou burocrático!
        return true;
    }

    setLinkDownloadQZ(link) {
        this.linkDownload = link;
    }

    getNomeImpressoraSelecionada() {
        return (localStorage.getItem('imp_qz_selecionada') ? localStorage.getItem('imp_qz_selecionada') : this.nomeImpressora);
    }

    setImpressora(nomeImpressora) {
        this.nomeImpressora = nomeImpressora;
        localStorage.setItem('imp_qz_selecionada', nomeImpressora);
    }

    appNaoEncontrado() {
        if (window.confirm("O aplicativo DRSystema Print não está aberto neste computador.\n\nDeseja verificar se ele está em execução ou baixar o instalador?")) {
            if (this.linkDownload) {
                window.open(this.linkDownload);
            }
        }
        return false;
    }

    /**
     * Lista todas as impressoras instaladas no Windows e abre o seletor visual
     */
    async selecionarImpressoraQZ(callBack = function () {}, storageKey = 'imp_qz_selecionada') {
        const conectado = await this.checarConexao();
        if (!conectado) {
            this.appNaoEncontrado();
            return false;
        }

        this.criarComponenteSelecaoImpressora();

        const selectElement = document.querySelector('#popupSelectQZ');
        selectElement.innerHTML = '<option value="">Carregando impressoras do Windows...</option>';

        selectElement.addEventListener('change', () => {
            const selecionada = selectElement.value;
            localStorage.setItem(storageKey, selecionada);
            this.setImpressora(selecionada);
            const container = document.getElementById("container_QZ_imp");
            if (container) container.remove();
            callBack(selecionada);
        });

        try {
            const resposta = await fetch(`${this.baseUrl}/printers`);
            const dados = await resposta.json();

            selectElement.innerHTML = '<option value="" style="display:none">Selecione uma impressora</option>';
            const impGravada = this.getNomeImpressoraSelecionada();

            (dados.impressoras || []).forEach(nome => {
                const opt = document.createElement('option');
                opt.value = nome;
                opt.textContent = nome;
                if (impGravada === nome || (!impGravada && dados.padrao === nome)) {
                    opt.selected = true;
                }
                selectElement.appendChild(opt);
            });
        } catch (e) {
            alert('Erro ao buscar impressoras do Windows: ' + e);
        }

        const container = document.getElementById('container_QZ_imp');
        if (container) container.style.display = 'block';
    }

    criarComponenteSelecaoImpressora() {
        const existente = document.getElementById('container_QZ_imp');
        if (existente) existente.remove();

        const html = `
            <div onclick="this.remove();" id="container_QZ_imp" style="background: #00000055; position: fixed; width: 100%; height: 100%; top: 0; left: 0; z-index: 9999998; display: none;">
                <div onclick="event.stopPropagation()" id="popUpSelectQZImp" style="z-index: 9999999; position: fixed; width: 340px; padding: 20px; top: 50%; left: 50%; transform: translate(-50%, -50%); background: linear-gradient(135deg, #1E3A8A, #0D9488); border-radius: 12px; box-shadow: 0px 8px 24px rgba(0,0,0,0.3); color: white;">
                    <div style="font-family: sans-serif; font-size: 18px; font-weight: bold; margin-bottom: 8px;">
                        🖨️ DRSystema Print
                    </div>
                    <div style="font-family: sans-serif; font-size: 13px; margin-bottom: 14px; opacity: 0.9;">
                        Selecione a impressora térmica instalada no Windows:
                    </div>
                    <select id="popupSelectQZ" style="padding: 10px; width: 100%; border-radius: 6px; border: none; font-family: sans-serif; font-size: 14px; font-weight: 600; background: white; color: #1E293B;"></select>
                </div>
            </div>`;
        document.body.insertAdjacentHTML("beforeend", html);
    }

    mostrarTelaCarregamento() {
        const existente = document.getElementById('popUpQZImprindo');
        if (existente) existente.remove();

        const html = `
            <div id="popUpQZImprindo" style="background: #00000044; position: fixed; width: 100%; height: 100%; top: 0; left: 0; z-index: 99999998; display: block;">
                <div style="z-index: 99999999; position: fixed; width: 280px; padding: 18px; top: 50%; left: 50%; transform: translate(-50%, -50%); background: linear-gradient(135deg, #1E3A8A, #0284C7); border-radius: 10px; box-shadow: 0px 6px 20px rgba(0,0,0,0.25); text-align: center; color: white;">
                    <div style="font-family: sans-serif; font-size: 16px; font-weight: 600;">
                        ⏳ Enviando impressão térmica...
                    </div>
                </div>
            </div>`;
        document.body.insertAdjacentHTML("beforeend", html);
    }

    /**
     * Imprime a NFC-e (Modelo 65) ou NF-e (Modelo 55) recebida de imprimir.php / cupom.php
     */
    async imprimir(urlDados, formato = 'base64', funcAntesDeImprimir = this.mostrarTelaCarregamento.bind(this), funcDepoisDeImprimir = () => {
        const el = document.getElementById("popUpQZImprindo");
        if (el) el.remove();
    }) {
        const impressora = this.getNomeImpressoraSelecionada();
        if (!impressora) {
            this.selecionarImpressoraQZ();
            return false;
        }

        const conectado = await this.checarConexao();
        if (!conectado) {
            this.appNaoEncontrado();
            return false;
        }

        funcAntesDeImprimir();

        try {
            // 1. Busca os dados binários Base64 gerados pelo PHP (imprimir.php / cupom.php)
            const respPhp = await fetch(urlDados);
            const base64Data = await respPhp.text();

            if (!base64Data || base64Data.trim().length === 0) {
                funcDepoisDeImprimir();
                alert('Aviso: Não há dados fiscais para impressão nesta nota.');
                return false;
            }

            // 2. Envia os bytes Base64 para o DRSystema Print no Windows
            const respPrint = await fetch(`${this.baseUrl}/print`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    printer: impressora,
                    data: base64Data.trim(),
                    type: 'raw',
                    docName: 'DRSystema NFC-e'
                })
            });

            funcDepoisDeImprimir();

            const resultado = await respPrint.json();
            if (!resultado.sucesso) {
                alert('Erro ao imprimir no Windows: ' + (resultado.erro || 'Erro desconhecido'));
                return false;
            }

            console.log('✅ Impressão enviada com sucesso para:', impressora);
            return true;

        } catch (erro) {
            funcDepoisDeImprimir();
            console.error('Falha na impressão:', erro);
            alert('Falha na comunicação com o DRSystema Print: ' + erro.message);
            return false;
        }
    }

    /**
     * Imprime comprovante TEF / Cartão (comprovante_cartao.php)
     */
    async imprimirPdf(fatura_id, funcAntesDeImprimir = this.mostrarTelaCarregamento.bind(this), funcDepoisDeImprimir = () => {
        const el = document.getElementById("popUpQZImprindo");
        if (el) el.remove();
    }) {
        const impressora = this.getNomeImpressoraSelecionada();
        if (!impressora) {
            this.selecionarImpressoraQZ();
            return false;
        }

        const conectado = await this.checarConexao();
        if (!conectado) {
            this.appNaoEncontrado();
            return false;
        }

        funcAntesDeImprimir();

        try {
            const formData = new FormData();
            formData.append('acao', 'comprovante_cartao');
            formData.append('fatura_id', fatura_id);

            const resp = await fetch(INCLUDE_PATH + '/_sis/pdv/repository/receber/comprovante_cartao.php', {
                method: 'POST',
                body: formData
            });

            const base64Texto = await resp.json();

            await fetch(`${this.baseUrl}/print`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    printer: impressora,
                    data: base64Texto,
                    type: 'raw',
                    docName: 'Comprovante Cartao'
                })
            });

            funcDepoisDeImprimir();
        } catch (e) {
            funcDepoisDeImprimir();
            console.error('Erro comprovante:', e);
        }
    }

    async imprimirPdfCan(fatura_id, funcAntesDeImprimir = this.mostrarTelaCarregamento.bind(this), funcDepoisDeImprimir = () => {
        const el = document.getElementById("popUpQZImprindo");
        if (el) el.remove();
    }) {
        const impressora = this.getNomeImpressoraSelecionada();
        if (!impressora) {
            this.selecionarImpressoraQZ();
            return false;
        }

        const conectado = await this.checarConexao();
        if (!conectado) {
            this.appNaoEncontrado();
            return false;
        }

        funcAntesDeImprimir();

        try {
            const formData = new FormData();
            formData.append('acao', 'comprovante_cartao');
            formData.append('fatura_id', fatura_id);

            const resp = await fetch(INCLUDE_PATH + '/_sis/pdv/repository/receber/comprovante_cartao_can.php', {
                method: 'POST',
                body: formData
            });

            const base64Texto = await resp.json();

            await fetch(`${this.baseUrl}/print`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    printer: impressora,
                    data: base64Texto,
                    type: 'raw',
                    docName: 'Comprovante Cancelamento'
                })
            });

            funcDepoisDeImprimir();
        } catch (e) {
            funcDepoisDeImprimir();
            console.error('Erro cancelamento:', e);
        }
    }
}

// Substitui a variável global ou permite uso direto como JSPrint
window.JSPrint = DRSystemaPrint;
window.DRSystemaPrint = DRSystemaPrint;
