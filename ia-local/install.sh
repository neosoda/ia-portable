#!/usr/bin/env bash
# =====================================================
# Installeur IA Local (Ollama Edition)
# =====================================================

set -euo pipefail

INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="ia"
SRC_DIR="$(dirname "$(realpath "$0")")"
SCRIPT_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"
OLLAMA_URL="http://127.0.0.1:11434"
BASE_MODEL="${IA_LOCAL_BASE_MODEL:-phi}"
CUSTOM_MODEL="${IA_LOCAL_MODEL:-ia-sysadmin}"

# Détections couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

main() {
  echo -e "${BLUE}=== Installation de l’assistant IA LOCAL (Ollama) ===${NC}"

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
  echo "Tout est prêt : Ollama + modèle '${CUSTOM_MODEL}' + commande 'ia'."
  echo "Essaie : ia \"combien de RAM libre ?\""
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "❌ Lance ce script avec sudo ou en root." >&2
    exit 1
  fi
}

install_sys_deps() {
  echo "→ Vérification dépendances système (curl, jq)..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y curl jq >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y curl jq >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    yum install -y curl jq >/dev/null
  else
    echo "❌ Gestionnaire de paquets non supporté (apt/dnf/yum attendu)." >&2
    exit 1
  fi
}

install_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    echo "→ Ollama est déjà installé."
    return
  fi

  echo "→ Téléchargement et installation de Ollama..."
  echo "⚠️  Le script d'installation Ollama sera téléchargé depuis ollama.com et exécuté en root."
  echo "   Inspectez-le si vous opérez dans un contexte de sécurité strict :"
  echo "   curl -fsSL https://ollama.com/install.sh | less"
  read -rp "   Continuer ? [o/N] " _ollama_confirm
  if [[ ! "$_ollama_confirm" =~ ^[oO](ui)?$ ]]; then
    echo "❌ Installation Ollama annulée." >&2
    exit 1
  fi

  local ollama_script
  ollama_script=$(mktemp -t ollama-install.XXXXXX.sh)
  trap "rm -f '$ollama_script'" RETURN
  curl -fsSL https://ollama.com/install.sh -o "$ollama_script"
  bash "$ollama_script"
  rm -f "$ollama_script"

  if ! command -v ollama >/dev/null 2>&1; then
    echo "❌ Ollama n'est pas disponible après installation." >&2
    exit 1
  fi
}

ensure_ollama_running() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now ollama >/dev/null 2>&1 || true
    if ! systemctl is-active --quiet ollama; then
      systemctl start ollama
    fi
  else
    if ! pgrep -f "ollama serve" >/dev/null 2>&1; then
      nohup ollama serve >/var/log/ollama.log 2>&1 &
      sleep 1
    fi
  fi

  echo "  ⏳ Attente du démarrage de Ollama..."
  local retries=0
  until curl --silent --fail --max-time 2 -o /dev/null "$OLLAMA_URL"; do
    retries=$((retries + 1))
    if (( retries > 30 )); then
      echo "❌ Temps d'attente dépassé. Ollama ne répond pas sur $OLLAMA_URL." >&2
      if command -v systemctl >/dev/null 2>&1; then
        echo "   Diagnostic : systemctl status ollama" >&2
      fi
      exit 1
    fi
    sleep 1
  done
  echo "  ✅ Ollama est en ligne."
}

model_exists() {
  local model="$1"
  ollama list | awk 'NR>1 {print $1}' | grep -Fxq "$model"
}

setup_model() {
  echo -e "${BLUE}→ Configuration du modèle IA (première exécution: quelques minutes)...${NC}"

  ensure_ollama_running

  if model_exists "$BASE_MODEL"; then
    echo "  ✅ Modèle de base déjà présent: $BASE_MODEL"
  else
    echo "  ⏬ Pull du modèle de base: $BASE_MODEL"
    ollama pull "$BASE_MODEL"
  fi

  if model_exists "$CUSTOM_MODEL"; then
    echo "  ✅ Modèle custom déjà présent: $CUSTOM_MODEL"
    return
  fi

  if [[ ! -f "${SRC_DIR}/Modelfile" ]]; then
    echo "❌ Erreur : Modelfile introuvable dans ${SRC_DIR}" >&2
    exit 1
  fi

  echo "  🧠 Build du modèle custom: $CUSTOM_MODEL"
  ollama create "$CUSTOM_MODEL" -f "${SRC_DIR}/Modelfile"
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
