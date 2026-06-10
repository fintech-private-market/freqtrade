#!/usr/bin/env bash

# ==============================================================================
# Freqtrade Force Sell/Exit Helper CLI
# ==============================================================================
# Uso: ./force_sell.sh <TRADE_ID|all> [order_type]
# Exemplo: ./force_sell.sh 1
#          ./force_sell.sh all
# ==============================================================================

TRADE_ID=${1:-"all"}
ORDER_TYPE=${2:-"market"}
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

# Extrair token
ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"access_token":"[^"]*' | grep -o '[^"]*$')

if [ -z "$ACCESS_TOKEN" ]; then
  echo -e "${RED}Erro na autenticação. Verifique se o bot está rodando e se as credenciais estão corretas.${NC}"
  echo "Resposta do servidor: $LOGIN_RESPONSE"
  exit 1
fi

echo -e "${GREEN}[✔] Autenticado com sucesso.${NC}"
echo -e "${YELLOW}[i] Enviando comando de Force Exit para a operação ID: $TRADE_ID...${NC}"

# 2. Executar o Force Exit
RESPONSE=$(curl -s -X POST "${API_URL}/api/v1/forceexit" \
     -H "Authorization: Bearer $ACCESS_TOKEN" \
     -H "Content-Type: application/json" \
     -d "{
           \"tradeid\": \"$TRADE_ID\",\
           \"ordertype\": \"$ORDER_TYPE\"\
         }")

# Exibir resultado formatado simples
if echo "$RESPONSE" | grep -q '"result"'; then
  MSG=$(echo "$RESPONSE" | grep -o '"result":"[^"]*' | grep -o '[^"]*$')
  echo -e "${GREEN}[✔] Sucesso! Venda forçada solicitada com sucesso.${NC}"
  echo -e "${GREEN}Mensagem: $MSG${NC}"
else
  echo -e "${RED}[!] Erro ao tentar forçar venda.${NC}"
  if echo "$RESPONSE" | grep -q '"error"'; then
    ERR_MSG=$(echo "$RESPONSE" | grep -o '"error":"[^"]*' | grep -o '[^"]*$')
    echo -e "${RED}Erro do Freqtrade: $ERR_MSG${NC}"
    if [[ "$ERR_MSG" == *"Invalid argument"* || "$ERR_MSG" == *"not found"* ]]; then
      echo -e "${YELLOW}[i] Dica: Esse erro geralmente ocorre se a operação ID já estiver fechada ou se o ID não existir.${NC}"
    fi
  else
    echo "Resposta: $RESPONSE"
  fi
fi
