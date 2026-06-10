# Freqtrade: Guia de Setup e Estratégias

Este documento resume o estado atual da configuração do seu bot de trading Freqtrade, comandos úteis para o dia a dia e detalhes das estratégias configuradas até agora.

> [!TIP]
> **Script de Inicialização Rápida (Bootstrap):**
> Se você precisar recriar o ambiente ou configurar o bot em outra máquina, execute o script [bootstrap.sh](file:///Users/roberto.porfiro/personal-code/freqtrade/bootstrap.sh) (`./bootstrap.sh`). Ele verifica os requisitos, cria as pastas necessárias, copia e corrige as estratégias, configura o `config.json`, baixa os dados históricos de teste e **inicia automaticamente o bot** exibindo o nome definido na sua configuração!

---

## 1. Estrutura do Projeto e Arquivos Chave

*   **Diretório Principal:** `/Users/roberto.porfiro/personal-code/freqtrade`
*   **Arquivo de Configuração:** [user_data/config.json](file:///Users/roberto.porfiro/personal-code/freqtrade/user_data/config.json)
    *   *WebUI:* Habilitada em `0.0.0.0:7001` (mapeada no host).
    *   *Credenciais:* Usuário `freqtrader` e Senha `SuperSecurePassword`.
    *   *Force Entry:* Habilitado (`"force_entry_enable": true`).
    *   *Stake per Trade:* 100 USDT (`"stake_amount": 100`).
    *   *Max Open Trades:* 10 (`"max_open_trades": 10`).
    *   *Timeframe Ativo:* 1 hora (`1h`).
    *   *Whitelist ativa:* 22 pares ativamente monitorados (incluindo BTC, ETH, SOL, AVAX, NEAR, DOGE, FET, RENDER, SUI, APT, PEPE, WIF).
*   **Pasta de Estratégias:** [user_data/strategies/](file:///Users/roberto.porfiro/personal-code/freqtrade/user_data/strategies/)
*   **Estratégia Ativa:** [Supertrend.py](file:///Users/roberto.porfiro/personal-code/freqtrade/user_data/strategies/Supertrend.py) (configurada em [docker-compose.yml](file:///Users/roberto.porfiro/personal-code/freqtrade/docker-compose.yml)).
*   **Branch Git Atual:** `feature/supertrend-config` (apontando para o fork `https://github.com/fintech-private-market/freqtrade.git`).
*   **Log do Bot:** [user_data/logs/freqtrade.log](file:///Users/roberto.porfiro/personal-code/freqtrade/user_data/logs/freqtrade.log)

---

## 2. Estratégias Configuradas

### A. Supertrend (Seguidora de Tendência - ATIVA)
*   **Arquivo:** [Supertrend.py](file:///Users/roberto.porfiro/personal-code/freqtrade/user_data/strategies/Supertrend.py)
*   **Comportamento:** Estratégia seguidora de tendência. Excelente proteção de capital na queda e ótimo aproveitamento de movimentos de alta (pumps). Compra quando os três indicadores de Supertrend mudam para a tendência de alta ("up").
*   **Parâmetros Ativos:**
    *   *Timeframe:* 1 hora (`1h`).
    *   *Startup Candles:* 199 (requer ~8 dias de dados históricos para começar a gerar sinais).
    *   *Stop-Loss Estático Inicial:* Reduzido para **-10.0%** (`stoploss = -0.10`) para melhor proteção de risco.
    *   *Trailing Stop (Stop Móvel):* Activado após **+5%** de ganho (`trailing_stop_positive_offset = 0.05`), depois segue o preço a **3% de distância** do topo (`trailing_stop_positive = 0.03`). Garante pelo menos **+2% de lucro** após activação.
    *   *Tabela de ROI (Realização de Lucro):* **35%** estático (`{"0": 0.35}`) — alvo alto para permitir que a tendência seja surfada através do Trailing Stop, saindo apenas em subidas parabólicas.

### B. SampleStrategy (Otimizada e Ajustada para Trailing Stop)
*   **Arquivo:** [SampleStrategy.py](file:///Users/roberto.porfiro/personal-code/freqtrade/user_data/strategies/SampleStrategy.py)
*   **Parâmetros Otimizados:** Salvos em [SampleStrategy.json](file:///Users/roberto.porfiro/personal-code/freqtrade/user_data/strategies/SampleStrategy.json).
*   **Configurações:**
    *   *Timeframe:* 15 minutos (`15m`).
    *   *Entrada (buy_rsi):* 19.
    *   *Filtro de Compra:* Exige que a TEMA esteja abaixo do meio das Bandas de Bollinger (`tema <= bb_middleband`).
    *   *Comportamento:* Funciona muito bem para capturar reversões após quedas severas (oversold bounce), mas não abre operações em mercados com tendência de alta contínua (pumps).

### C. BbandRsi (Reversão à Média)
*   **Arquivo:** [BbandRsi.py](file:///Users/roberto.porfiro/personal-code/freqtrade/user_data/strategies/BbandRsi.py)
*   **Comportamento:** Compra quando o RSI cai abaixo de 30 e o preço sai das Bandas de Bollinger inferiores, buscando rebotes rápidos de preço.

---

## 3. Guia de Comandos Úteis (Cheat Sheet)

Execute estes comandos a partir da pasta `/Users/roberto.porfiro/personal-code/freqtrade`:

### 📥 Download de Dados Históricos
Para baixar dados de velas para novos testes (ex: últimos 30 dias para BTC e ETH nas velas de 5m e 1h):
```bash
docker compose run --rm freqtrade download-data --pairs BTC/USDT ETH/USDT --timeframes 5m 1h --exchange binance --days 30
```

### 📊 Executar Backtesting (Simulação Passada)
Testar uma estratégia específica contra os dados baixados:
```bash
# Testar a SampleStrategy (usa 15m por padrão)
docker compose run --rm freqtrade backtesting --config user_data/config.json --strategy SampleStrategy

# Testar a Supertrend (especificando velas de 1h)
docker compose run --rm freqtrade backtesting --config user_data/config.json --strategy Supertrend --timeframe 1h
```

### 🧠 Rodar Otimização Automática (Hyperopt)
Fazer o Freqtrade descobrir as melhores configurações de RSI e ROI para uma estratégia:
```bash
docker compose run --rm freqtrade hyperopt --config user_data/config.json --strategy SampleStrategy --epochs 20 --hyperopt-loss SharpeHyperOptLoss
```

### 🚀 Gerenciar o Bot em Tempo Real (Dry-run / Simulador)
Para aplicar novas alterações de código, parâmetros ou comandos no `docker-compose.yml`:
```bash
# Iniciar/Recriar o bot aplicando alterações do docker-compose.yml (MUITO IMPORTANTE)
docker compose up -d

# Visualizar logs em tempo real
docker compose logs -f freqtrade

# Parar o bot
docker compose down

# Reiniciar o bot (apenas para atualizar arquivos como o config.json, sem mudar o docker-compose.yml)
docker compose restart
```

### 🛠️ Scripts Auxiliares (Comandos Manuais via CLI)
Você também pode forçar a compra ou a venda de ativos diretamente pelo terminal sem abrir o navegador:
```bash
# Forçar compra manual (ex: BTC/USDT)
./force_buy.sh BTC/USDT

# Forçar venda manual por ID do Trade (ex: ID 2)
./force_sell.sh 2

# Forçar venda de TODOS os trades ativos na simulação
./force_sell.sh all
```

---

## 4. Monitoramento

Acesse a interface gráfica no seu navegador em:
👉 **[http://localhost:7001](http://localhost:7001)**
*   *Usuário:* `freqtrader`
*   *Senha:* `SuperSecurePassword`

*Nota: Se encontrar erro 403 Forbidden ao acessar após uma reinicialização, basta atualizar a página (F5) no navegador.*

---

## 5. Estudo de Caso: O Funcionamento Prático do Trailing Stop (Trade #11 - ATOM/USDT)

Este exemplo prático de simulação real ilustra como a configuração de **Trailing Stop de 2% ativo desde o início** (`trailing_only_offset_is_reached = false`) agiu para limitar um prejuízo em potencial na SampleStrategy quando a moeda subiu um pouco e depois reverteu.

### Fatos da Operação:
*   **Par:** `ATOM/USDT` (Trade ID: 11)
*   **Preço de Entrada (Entry):** `1.98`
*   **Preço Máximo Atingido (Peak):** `2.013` (valorização de **+1.67%**).
*   **Preço de Saída (Exit):** `1.972`
*   **Resultado Líquido (PnL):** `-0.60%` (incluindo as taxas simuladas da exchange).

### A Lógica Matemática em Ação:
1.  **Ajuste Dinâmico:** Conforme o preço subiu até a máxima de `2.013`, o Freqtrade recalculou e arrastou o Stop-Loss para cima, fixando-o exatamente a 2% de distância do topo:
    $$\text{Novo Stop-Loss} = 2.013 \times (1 - 0.02) = 1.9727$$
2.  **Mitigação do Risco:** Quando a moeda reverteu a tendência e caiu, ela bateu no novo stop-loss recalculado de `1.9727`, executando a venda a mercado a `1.972`.
3.  **Comparação de Cenários:**
    *   *Sem Trailing Stop:* O bot teria segurado a moeda até bater no stop original de `1.9404` (ou `-4.2%`), resultando em um prejuízo de **-2.0%** (ou **-4.2%**).
    *   *Com Trailing Stop:* A perda foi reduzida para apenas **-0.60%**, protegendo 70% do risco original da operação!

---

## 6. Resultados da Validação e Otimização (SampleStrategy)

Executamos com sucesso o plano de validação e otimização dos parâmetros da estratégia `SampleStrategy` para os timeframes de 5m e 15m antes da migração para o Supertrend.

### 6.1. Comparação de Métricas (Backtest 30 dias)

| Métrica | Estratégia Inicial (5m) | Otimizada (5m) | Otimizada Final (15m) |
| :--- | :--- | :--- | :--- |
| **Timeframe** | 5m | 5m | **15m** |
| **Total de Trades** | 284 | 21 | **28** (Equilibrado) |
| **PnL Total (%)** | -11.04% (-110.36 USDT) | +0.48% (+4.80 USDT) | **+2.12%** (+21.20 USDT) |
| **Taxa de Acerto** | 37.0% (105 W / 179 L) | 71.4% (15 W / 6 L) | **78.6%** (22 W / 6 L) |
| **Drawdown Máximo** | 13.28% (136.08 USDT) | 0.00% (0.013 USDT) | **0.00%** (0.047 USDT) |
| **Média de Duração** | 10 horas e 46 minutos | 20 horas e 49 minutos | **9 horas e 58 minutos** |

---

## 7. Registro de Incidentes e Resolução (Junho/2026)

### A. Inatividade do Bot durante Alta do Mercado (Pumps)
*   **Problema:** O bot estava inativo e não abria nenhuma ordem, mesmo com movimentos expressivos de alta no Bitcoin e outras altcoins da whitelist.
*   **Causa:** A estratégia então ativa (`SampleStrategy`) estava com o parâmetro `buy_rsi` otimizado em `19` (sobrevenda extrema) e possuía uma trava de entrada que só permitia compras se o indicador `tema` estivesse abaixo da linha média do Bollinger Bands (`tema <= bb_middleband`). Durante mercados de alta (pumps), essas condições nunca eram atingidas simultaneamente.
*   **Solução:** Alteramos a estratégia ativa para a **`Supertrend`** no timeframe de **`1h`**, que foi projetada especificamente para seguir tendências de alta e atuar em cruzamentos de médias e rompimentos.

### B. Persistência de Comandos no Docker Compose
*   **Problema:** Após configurar `--strategy Supertrend` no [docker-compose.yml](file:///Users/roberto.porfiro/personal-code/freqtrade/docker-compose.yml), a inicialização do bot via `docker compose restart` não aplicou a nova estratégia, mantendo o bot preso na `SampleStrategy`.
*   **Causa:** O comando `restart` apenas reinicia o container atual e não recria a instância com as novas diretivas do arquivo YAML.
*   **Solução:** Utilizou-se o comando `docker compose up -d` para forçar a recriação do container.
*   **Resultado Imediato:** O bot inicializou corretamente com a **Supertrend** no timeframe de **1h** e abriu de imediato duas operações em modo dry-run:
    *   **`LINK/USDT`**: Compra a `$7.907` (Ordem executada/fulfilled).
    *   **`NEAR/USDT`**: Compra a `$2.174` (Ordem executada/fulfilled).

### C. Restrição de Push no GitHub (Deploy Key)
*   **Problema:** Tentativa de enviar a nova branch local (`feature/supertrend-config`) para o fork originou o erro `403 Forbidden - Permission denied to deploy key`.
*   **Causa:** A chave SSH configurada para autenticar com o domínio `github.com` (`id_ed25519_robertoporfiro`) está cadastrada no GitHub como uma "Deploy Key" (chave de implantação/CI-CD) de algum repositório específico, o que impede que o GitHub a utilize como uma credencial de escrita ampla em outros repositórios.
*   **Ações Recomendadas:** 
    1. Ajustar o [~/.ssh/config](file:///Users/roberto.porfiro/.ssh/config) para apontar para a chave pessoal do usuário (ex: `id_ed25519` ou `id_rsa`) que responde positivamente ao teste `ssh -T git@github.com`.
    2. Alternativamente, reverter a URL para HTTPS (`git remote set-url origin https://github.com/fintech-private-market/freqtrade.git`) e autenticar usando um **Personal Access Token (PAT)** clássico do GitHub com permissão de `repo`.

---

## 8. Replicação e Implantação em Novos Ambientes

Para replicar este robô com a mesma configuração em outra máquina (VPS, Lightsail, ou ambiente local), siga os passos abaixo. O repositório já está preparado e versionado com todos os templates e estratégias necessários.

### Passos para Implantação:

1. **Clonar o Repositório e Acessar a Branch correta:**
   ```bash
   git clone https://github.com/fintech-private-market/freqtrade.git
   cd freqtrade
   git checkout feature/supertrend-config
   ```

2. **Tornar o script executável e iniciar o bootstrap:**
   ```bash
   chmod +x bootstrap.sh
   ./bootstrap.sh
   ```

### O que o script de Bootstrap realiza automaticamente:
* **Estrutura de Pastas:** Reconhece e cria as pastas internas necessárias de dados do usuário (`user_data/`, `user_data/strategies/`, `user_data/logs/`, etc.), as quais estão excluídas do Git por segurança.
* **Cópia de Configuração:** Detecta o arquivo de modelo seguro [config_fintech.example.json](file:///Users/roberto.porfiro/personal-code/freqtrade/config_examples/config_fintech.example.json) e o copia como a configuração principal do bot (`user_data/config.json`).
* **Montagem das Estratégias:** Como as estratégias customizadas ([Supertrend.py](file:///Users/roberto.porfiro/personal-code/freqtrade/user_data/strategies/Supertrend.py), [SampleStrategy.py](file:///Users/roberto.porfiro/personal-code/freqtrade/user_data/strategies/SampleStrategy.py) e [BbandRsi.py](file:///Users/roberto.porfiro/personal-code/freqtrade/user_data/strategies/BbandRsi.py)) foram forçadas no controle de versão do Git, elas já estarão disponíveis na pasta de estratégias do robô no novo ambiente.
* **Download de Dados:** Realiza a busca inicial de dados históricos de velas para Binance.
* **Inicialização:** Sobe o contêiner via Docker Compose rodando a **Supertrend** no timeframe de **1h** exposta na porta de host **7001**.
