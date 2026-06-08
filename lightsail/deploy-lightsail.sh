#!/usr/bin/env bash
# ==============================================================================
# Freqtrade - AWS Lightsail Deployment Script
# ==============================================================================
# Run this script on a fresh Lightsail Ubuntu instance via SSH:
#
#   ssh ubuntu@<LIGHTSAIL_IP>
#   curl -fsSL https://raw.githubusercontent.com/fintech-private-market/freqtrade/feature/supertrend-config/lightsail/deploy-lightsail.sh | bash
#
# Or after cloning the repo:
#   chmod +x lightsail/deploy-lightsail.sh
#   ./lightsail/deploy-lightsail.sh
#
# Requirements: Ubuntu 22.04 LTS (recommended Lightsail plan: $10/month, 2GB RAM)
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REPO_URL="https://github.com/fintech-private-market/freqtrade.git"
BRANCH="feature/supertrend-config"
INSTALL_DIR="$HOME/freqtrade"

echo -e "${GREEN}=== Freqtrade - AWS Lightsail Deployment ===${NC}"
echo -e "${YELLOW}Target directory: $INSTALL_DIR${NC}"

# ------------------------------------------------------------------------------
# 1. System Update & Dependencies
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[1/6] Updating system packages...${NC}"
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y git curl ca-certificates gnupg lsb-release

# ------------------------------------------------------------------------------
# 2. Install Docker Engine
# ------------------------------------------------------------------------------
if ! command -v docker &> /dev/null; then
  echo -e "\n${YELLOW}[2/6] Installing Docker Engine...${NC}"
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  echo -e "${GREEN}[✔] Docker installed. Note: You may need to log out/in for group changes.${NC}"
else
  echo -e "\n${GREEN}[2/6] Docker already installed: $(docker --version)${NC}"
fi

# Install Docker Compose plugin if not available
if ! docker compose version &> /dev/null 2>&1; then
  echo -e "${YELLOW}Installing Docker Compose plugin...${NC}"
  sudo apt-get install -y docker-compose-plugin
fi
echo -e "${GREEN}[✔] Docker Compose: $(docker compose version)${NC}"

# ------------------------------------------------------------------------------
# 3. Clone / Update the Repository
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/6] Cloning repository (branch: $BRANCH)...${NC}"
if [ -d "$INSTALL_DIR/.git" ]; then
  echo -e "${YELLOW}[i] Repository already exists. Pulling latest changes...${NC}"
  cd "$INSTALL_DIR"
  git fetch origin
  git checkout "$BRANCH"
  git pull origin "$BRANCH"
else
  git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi
echo -e "${GREEN}[✔] Repository ready at $INSTALL_DIR${NC}"

# ------------------------------------------------------------------------------
# 4. Create user_data structure and config.json
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/6] Setting up user_data structure...${NC}"
cd "$INSTALL_DIR"

# Create directory structure
mkdir -p user_data/strategies user_data/logs user_data/data user_data/backtest_results

# Copy config template if config.json doesn't exist yet
if [ ! -f "user_data/config.json" ]; then
  if [ -f "config_examples/config_fintech.example.json" ]; then
    cp config_examples/config_fintech.example.json user_data/config.json
    echo -e "${GREEN}[✔] config.json created from config_fintech.example.json${NC}"
    echo -e "${RED}[!] IMPORTANT: Edit user_data/config.json and set your Binance API keys!${NC}"
    echo -e "${RED}    nano user_data/config.json${NC}"
  else
    echo -e "${RED}[!] config_fintech.example.json not found. Please create user_data/config.json manually.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}[✔] user_data/config.json already exists.${NC}"
fi

# Ensure strategies are in place (they are tracked in git on this branch)
if [ -f "user_data/strategies/Supertrend.py" ]; then
  echo -e "${GREEN}[✔] Strategies already present (from git).${NC}"
else
  echo -e "${RED}[!] Strategies not found. Please check the repository.${NC}"
fi

# ------------------------------------------------------------------------------
# 5. Build and Start the Container
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[5/6] Building image and starting Freqtrade...${NC}"
cd "$INSTALL_DIR"

# Use lightsail-specific compose file
docker compose -f lightsail/docker-compose.lightsail.yml build --no-cache
docker compose -f lightsail/docker-compose.lightsail.yml up -d

if [ $? -eq 0 ]; then
  echo -e "${GREEN}[✔] Freqtrade container started successfully!${NC}"
else
  echo -e "${RED}[!] Error starting container. Check logs with: docker compose -f lightsail/docker-compose.lightsail.yml logs${NC}"
  exit 1
fi

# ------------------------------------------------------------------------------
# 6. Setup systemd to auto-start Docker on reboot (optional but recommended)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[6/6] Enabling Docker service on system startup...${NC}"
sudo systemctl enable docker
echo -e "${GREEN}[✔] Docker will start automatically on reboot.${NC}"

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
INSTANCE_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "<LIGHTSAIL_IP>")

echo -e "\n${GREEN}=======================================================${NC}"
echo -e "${GREEN} Deployment Concluído com Sucesso!${NC}"
echo -e "${GREEN}=======================================================${NC}"
echo -e ""
echo -e "  Bot a correr em:  ${YELLOW}http://$INSTANCE_IP:7001${NC}"
echo -e "  (a porta 7001 está exposta apenas em localhost)"
echo -e ""
echo -e "  Para aceder remotamente, use um túnel SSH:"
echo -e "  ${YELLOW}ssh -L 7001:localhost:7001 ubuntu@$INSTANCE_IP${NC}"
echo -e "  Depois aceda em: ${YELLOW}http://localhost:7001${NC}"
echo -e ""
echo -e "  Credenciais FreqUI:"
echo -e "    Utilizador: ${GREEN}freqtrader${NC}"
echo -e "    Password:   ${GREEN}SuperSecurePassword${NC}"
echo -e ""
echo -e "  Comandos úteis:"
echo -e "    Ver logs:    ${YELLOW}docker compose -f ~/freqtrade/lightsail/docker-compose.lightsail.yml logs -f${NC}"
echo -e "    Parar bot:   ${YELLOW}docker compose -f ~/freqtrade/lightsail/docker-compose.lightsail.yml down${NC}"
echo -e "    Reiniciar:   ${YELLOW}docker compose -f ~/freqtrade/lightsail/docker-compose.lightsail.yml restart${NC}"
echo -e ""
echo -e "${RED}[!] LEMBRE-SE: Configure as chaves da Binance em ~/freqtrade/user_data/config.json${NC}"
echo -e "${GREEN}=======================================================${NC}"
