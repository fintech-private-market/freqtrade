#!/usr/bin/env bash

# ==============================================================================
# Freqtrade Bootstrap Script
# ==============================================================================
# Este script automatiza o setup e inicialização rápida do ambiente Freqtrade.
# Certifique-se de que o Docker está em execução antes de iniciar.
# ==============================================================================

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sem cor

echo -e "${GREEN}=== Iniciando Bootstrap do Freqtrade ===${NC}"

# 1. Verificar se o Docker está instalado e acessível
if ! [ -x "$(command -v docker)" ]; then
  echo -e "${RED}Erro: Docker não encontrado. Instale o Docker antes de continuar.${NC}" >&2
  exit 1
fi

if ! docker ps > /dev/null 2>&1; then
  echo -e "${RED}Erro: O Docker daemon não está rodando. Por favor, inicie o Docker Desktop.${NC}" >&2
  exit 1
fi
echo -e "${GREEN}[✔] Docker está ativo e acessível.${NC}"

# 2. Criar a estrutura user_data caso não exista
if [ ! -d "user_data" ]; then
  echo -e "${YELLOW}[i] Diretório 'user_data' não encontrado. Criando estrutura inicial via Docker...${NC}"
  docker compose run --rm freqtrade create-userdir --userdir user_data
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✔] Diretório 'user_data' criado com sucesso.${NC}"
  else
    echo -e "${RED}Erro ao criar o diretório 'user_data'.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}[✔] Diretório 'user_data' já existe.${NC}"
fi

# 3. Configurar arquivo config.json caso não exista
if [ ! -f "user_data/config.json" ]; then
  if [ -f "config_examples/config_fintech.example.json" ]; then
    echo -e "${YELLOW}[i] 'user_data/config.json' não encontrado. Gerando a partir de config_fintech.example.json...${NC}"
    cp config_examples/config_fintech.example.json user_data/config.json
    echo -e "${GREEN}[✔] 'config.json' configurado a partir de config_fintech.example.json (Supertrend/1h/22 pares).${NC}"
  elif [ -f "config_examples/config_binance.example.json" ]; then
    echo -e "${YELLOW}[i] 'user_data/config.json' não encontrado. Gerando a partir do exemplo da Binance...${NC}"
    
    # Copia o exemplo
    cp config_examples/config_binance.example.json user_data/config.json
    
    # Habilita o API Server para o FreqUI funcionar em 0.0.0.0:8080 por padrão
    # Utilizando sed para habilitar o servidor de API
    sed -i.bak 's/"enabled": false/"enabled": true/g' user_data/config.json
    sed -i.bak 's/"listen_ip_address": "127.0.0.1"/"listen_ip_address": "0.0.0.0"/g' user_data/config.json
    sed -i.bak 's/"force_entry_enable": false/"force_entry_enable": true/g' user_data/config.json
    rm -f user_data/config.json.bak
    
    # Insere o BTC/USDT na whitelist se não estiver lá
    sed -i.bak 's/"pair_whitelist": \[/"pair_whitelist": \[\n            "BTC\/USDT",/g' user_data/config.json
    rm -f user_data/config.json.bak
    
    echo -e "${GREEN}[✔] 'config.json' configurado com FreqUI ativo (porta 8080) e BTC/USDT na whitelist.${NC}"
  else
    echo -e "${YELLOW}[i] Gerando configuração padrão interativa...${NC}"
    docker compose run --rm freqtrade new-config -c user_data/config.json
  fi
else
  echo -e "${GREEN}[✔] Arquivo 'user_data/config.json' já existe.${NC}"
fi

# 4. Copiar as estratégias caso ainda não estejam na pasta do usuário
mkdir -p user_data/strategies

# Copiar SampleStrategy se não existir
if [ ! -f "user_data/strategies/SampleStrategy.py" ] && [ -f "freqtrade/templates/sample_strategy.py" ]; then
  cp freqtrade/templates/sample_strategy.py user_data/strategies/SampleStrategy.py
  echo -e "${GREEN}[✔] SampleStrategy.py copiada para a pasta do usuário.${NC}"
fi

# Copiar estratégias do repositório clonado se disponível
STRATEGIES_REPO="../freqtrade-strategies/user_data/strategies"
if [ -d "$STRATEGIES_REPO" ]; then
  echo -e "${YELLOW}[i] Repositório externo de estratégias detectado. Copiando exemplos populares...${NC}"
  
  # Supertrend
  if [ -f "$STRATEGIES_REPO/Supertrend.py" ] && [ ! -f "user_data/strategies/Supertrend.py" ]; then
    cp "$STRATEGIES_REPO/Supertrend.py" user_data/strategies/Supertrend.py
    # Aplica a correção do Pandas na linha 193
    sed -i.bak 's/result.fillna(0, inplace=True)/result\x5b'\''ST'\''\x5d = result\x5b'\''ST'\''\x5d.fillna(0)\n        result\x5b'\''STX'\''\x5d = result\x5b'\''STX'\''\x5d.fillna("")/g' user_data/strategies/Supertrend.py
    rm -f user_data/strategies/Supertrend.py.bak
    echo -e "${GREEN}[✔] Supertrend.py importada e corrigida.${NC}"
  fi

  # BbandRsi
  if [ -f "$STRATEGIES_REPO/berlinguyinca/BbandRsi.py" ] && [ ! -f "user_data/strategies/BbandRsi.py" ]; then
    cp "$STRATEGIES_REPO/berlinguyinca/BbandRsi.py" user_data/strategies/BbandRsi.py
    echo -e "${GREEN}[✔] BbandRsi.py importada.${NC}"
  fi
fi

# 5. Baixar dados iniciais de 30 dias para testes
echo -e "${YELLOW}[i] Baixando últimos 30 dias de dados do BTC/USDT e ETH/USDT para simulações...${NC}"
docker compose run --rm freqtrade download-data --pairs BTC/USDT ETH/USDT --timeframes 5m 1h --exchange binance --days 30
if [ $? -eq 0 ]; then
  echo -e "${GREEN}[✔] Dados históricos baixados com sucesso.${NC}"
else
  echo -e "${RED}[!] Aviso: Falha ao baixar dados históricos automaticamente. Você pode tentar manualmente depois.${NC}"
fi

# 6. Extrair nome do bot e iniciar o contêiner automaticamente
BOT_NAME=$(python3 -c "import json; print(json.load(open('user_data/config.json'))['bot_name'])" 2>/dev/null || echo "freqtrade")

echo -e "\n${YELLOW}[i] Iniciando o bot '$BOT_NAME' em modo simulado (Dry-run)...${NC}"
docker compose up -d

if [ $? -eq 0 ]; then
  echo -e "${GREEN}[✔] Bot '$BOT_NAME' iniciado com sucesso via Docker Compose.${NC}"
else
  echo -e "${RED}[!] Erro ao tentar iniciar o bot via Docker Compose.${NC}"
fi

echo -e "\n${GREEN}=======================================================${NC}"
echo -e "${GREEN} Setup de Bootstrap Concluído com Sucesso!${NC}"
echo -e "${GREEN}=======================================================${NC}"
echo -e "O seu bot de trading '${YELLOW}$BOT_NAME${NC}' já está em execução!"
echo -e "Acesse o painel gráfico no navegador para interagir:"
echo -e "  👉 ${YELLOW}http://localhost:7001${NC} (Porta mapeada no host para a 8080 do contêiner)"
echo -e "  Credenciais de acesso:"
echo -e "    Usuário: ${GREEN}freqtrader${NC}"
echo -e "    Senha:   ${GREEN}SuperSecurePassword${NC}"
echo -e "\nPara rodar simulações de backtesting no terminal:"
echo -e "  ${YELLOW}docker compose run --rm freqtrade backtesting --config user_data/config.json --strategy Supertrend --timeframe 1h${NC}"
echo -e "=======================================================\n"
