#!/usr/bin/env bash
# =====================================================
# Installeur IA Local (Ollama Edition)
# =====================================================

set -euo pipefail

INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="ia"
SRC_DIR="$(dirname "$(realpath "$0")")"
SCRIPT_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"

# Détections couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

main() {
  echo -e "${BLUE}=== Installation de l’assistant IA LOCAL (Ollama + Phi-2) ===${NC}"

  require_root
  
  # 1. Vérif dépendances système
  install_sys_deps

  # 2. Installation Ollama
  install_ollama

  # 3. Préparation du modèle IA
  setup_model

  # 4. Installation du script client
  install_client_script
  
  # 5. Alias
  ensure_alias

  echo -e "\n${GREEN}✅ Installation terminée !${NC}"
  echo "Le serveur Ollama tourne en fond."
  echo "Essaie :  ia 'combien de RAM libre ?'"
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "❌ Lance ce script avec sudo ou en root." >&2
    exit 1
  fi
}

install_sys_deps() {
  echo "→ Vérification curl/jq..."
  if command -v apt-get >/dev/null; then
    apt-get update -qq && apt-get install -y curl jq >/dev/null
  elif command -v dnf >/dev/null; then
    dnf install -y curl jq >/dev/null
  elif command -v yum >/dev/null; then
    yum install -y curl jq >/dev/null
  fi
}

install_ollama() {
  if command -v ollama >/dev/null; then
    echo "→ Ollama est déjà installé."
  else
    echo "→ Téléchargement et installation de Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
  fi
}

setup_model() {
  echo -e "${BLUE}→ Configuration du modèle IA (Ceci peut prendre quelques minutes)...${NC}"
  
  # On s'assure que le service tourne
  if ! systemctl is-active --quiet ollama; then
    systemctl start ollama
  fi

  echo "  ⏳ Attente du démarrage de Ollama..."
  local retries=0
  while ! curl -s -f -o /dev/null "http://localhost:11434"; do
    sleep 2
    ((retries++))
    if ((retries > 15)); then
      echo "❌ Temps d'attente dépassé. Ollama ne répond pas."
      echo "   Tente : systemctl status ollama"
      exit 1
    fi
  done
  echo "  ✅ Ollama est en ligne."

  echo "  1. Pulling base model (phi)..."
  ollama pull phi

  echo "  2. Building custom model 'ia-sysadmin'..."
  # On lance la création depuis le Modelfile situé dans le même dossier
  if [[ -f "${SRC_DIR}/Modelfile" ]]; then
    ollama create ia-sysadmin -f "${SRC_DIR}/Modelfile"
  else
    echo "❌ Erreur : Modelfile introuvable dans ${SRC_DIR}"
    exit 1
  fi
}

install_client_script() {
  echo "→ Installation du client dans ${INSTALL_DIR}..."
  install -m 0755 "${SRC_DIR}/ia.sh" "$SCRIPT_PATH"
}

ensure_alias() {
  if ! grep -q "alias ia=" /etc/bash.bashrc; then
    echo "alias ia='/usr/local/bin/ia'" >> /etc/bash.bashrc
  fi
}

main "$@"
