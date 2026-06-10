#!/usr/bin/env bash

# ==============================================================================
# Freqtrade Force Buy/Entry Helper CLI
# ==============================================================================
# Uso: ./force_buy.sh <PAIR> [side]
# Exemplo: ./force_buy.sh BTC/USDT
# ==============================================================================

PAIR=${1:-"BTC/USDT"}
SIDE=${2:-"long"}
API_URL="http://localhost:7001"
USERNAME="freqtrader"
PASSWORD="SuperSecurePassword"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[i] Autenticando com o Freqtrade API em $API_URL...${NC}"

# 1. Login para pegar o Token de Acesso JWT
LOGIN_RESPONSE=$(curl -s -X POST --user "${USERNAME}:${PASSWORD}" "${API_URL}/api/v1/token/login")

# Extrair token (usando regex para evitar dependência do jq)
ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"access_token":"[^"]*' | grep -o '[^"]*$')

if [ -z "$ACCESS_TOKEN" ]; then
  echo -e "${RED}Erro na autenticação. Verifique se o bot está rodando e se as credenciais estão corretas.${NC}"
  echo "Resposta do servidor: $LOGIN_RESPONSE"
  exit 1
fi

echo -e "${GREEN}[✔] Autenticado com sucesso.${NC}"
echo -e "${YELLOW}[i] Enviando comando de Force Entry para o par $PAIR ($SIDE)...${NC}"

# 2. Executar o Force Enter
RESPONSE=$(curl -s -X POST "${API_URL}/api/v1/forceenter" \
     -H "Authorization: Bearer $ACCESS_TOKEN" \
     -H "Content-Type: application/json" \
     -d "{
           \"pair\": \"$PAIR\",\
           \"side\": \"$SIDE\",\
           \"order_type\": \"market\"\
         }")

# Exibir resultado formatado simples
if echo "$RESPONSE" | grep -q '"trade_id"'; then
  TRADE_ID=$(echo "$RESPONSE" | grep -o '"trade_id":[0-9]*' | grep -o '[0-9]*$')
  echo -e "${GREEN}[✔] Sucesso! Entrada forçada com sucesso para $PAIR (Trade ID: $TRADE_ID).${NC}"
else
  echo -e "${RED}[!] Erro ao tentar forçar entrada.${NC}"
  if echo "$RESPONSE" | grep -q '"error"'; then
    ERR_MSG=$(echo "$RESPONSE" | grep -o '"error":"[^"]*' | grep -o '[^"]*$')
    echo -e "${RED}Erro do Freqtrade: $ERR_MSG${NC}"
    if [[ "$ERR_MSG" == *"already open"* ]]; then
      echo -e "${YELLOW}[i] Dica: O par $PAIR já possui uma operação aberta no momento.${NC}"
    fi
  else
    echo "Resposta: $RESPONSE"
  fi
fi
