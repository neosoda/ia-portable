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
BASE_MODEL="${IA_LOCAL_BASE_MODEL:-qwen2.5:0.5b-instruct}"
CUSTOM_MODEL="${IA_LOCAL_MODEL:-ia-sysadmin}"

# Détections couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

choose_model() {
  if [[ -n "${IA_LOCAL_BASE_MODEL:-}" ]]; then
    return
  fi

  echo -e "${YELLOW}Quel modèle IA voulez-vous utiliser ?${NC}"
  echo ""
  echo "  1) Qwen 0.5B (par défaut)"
  echo "     ⚡ Rapide (1-2 sec), léger (340 MB), peu de RAM"
  echo "     ❌ Moins puissant pour requêtes complexes"
  echo ""
  echo "  2) Qwen 1.5B"
  echo "     💪 Plus puissant, meilleure qualité"
  echo "     🐌 Plus lent (5-10 sec), lourd (986 MB), plus de RAM"
  echo ""
  read -rp "Choix [1/2] (défaut: 1) : " model_choice
  model_choice=${model_choice:-1}

  if ! [[ "$model_choice" =~ ^[12]$ ]]; then
    echo "❌ Choix invalide (doit être 1 ou 2), utilisation du défaut (0.5B)"
    model_choice=1
  fi

  case "$model_choice" in
    1)
      BASE_MODEL="qwen2.5:0.5b-instruct"
      echo "→ Sélection : Qwen 0.5B ✓"
      ;;
    2)
      BASE_MODEL="qwen2.5-coder:1.5b-instruct"
      echo "→ Sélection : Qwen 1.5B ✓"
      ;;
  esac
  echo ""
}

main() {
  echo -e "${BLUE}=== Installation de l'assistant IA LOCAL (Ollama) ===${NC}"
  echo ""

  require_root

  # 0. Choix du modèle
  choose_model

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
  if [[ ! "$_ollama_confirm" =~ ^[oO]([uU][iI])?$ ]]; then
    echo "❌ Installation Ollama annulée." >&2
    exit 1
  fi

  local ollama_script
  ollama_script=$(mktemp -t ollama-install.XXXXXX.sh)
  trap "rm -f '$ollama_script'" RETURN
  curl -fsSL https://ollama.com/install.sh -o "$ollama_script"
  bash "$ollama_script"

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
  local max_wait="${IA_LOCAL_STARTUP_TIMEOUT_SECONDS:-30}"
  until curl --silent --fail --max-time 2 -o /dev/null "$OLLAMA_URL"; do
    retries=$((retries + 1))
    if (( retries > max_wait )); then
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
  ollama list | awk 'NR>1 {print $1}' | grep -Fq "$model"
}

IA_STATE_FILE="/var/lib/ia/base_model"

setup_model() {
  echo -e "${BLUE}→ Configuration du modèle IA (première exécution: quelques minutes)...${NC}"

  ensure_ollama_running

  if model_exists "$BASE_MODEL"; then
    echo "  ✅ Modèle de base déjà présent: $BASE_MODEL"
  else
    echo "  ⏬ Pull du modèle de base: $BASE_MODEL"
    ollama pull "$BASE_MODEL"
  fi

  local stored_base=""
  [[ -f "$IA_STATE_FILE" ]] && stored_base=$(cat "$IA_STATE_FILE")

  if model_exists "$CUSTOM_MODEL" && [[ "$stored_base" == "$BASE_MODEL" ]]; then
    echo "  ✅ Modèle custom déjà présent: $CUSTOM_MODEL ($BASE_MODEL)"
    return
  fi

  if model_exists "$CUSTOM_MODEL" && [[ -n "$stored_base" && "$stored_base" != "$BASE_MODEL" ]]; then
    echo "  🔄 Base changée ($stored_base → $BASE_MODEL), recréation de $CUSTOM_MODEL..."
    ollama rm "$CUSTOM_MODEL" 2>/dev/null || true
  fi

  if [[ ! -f "${SRC_DIR}/Modelfile" ]]; then
    echo "❌ Erreur : Modelfile introuvable dans ${SRC_DIR}" >&2
    exit 1
  fi

  echo "  🧠 Build du modèle custom: $CUSTOM_MODEL"
  local modelfile_tmp
  modelfile_tmp=$(mktemp -t modelfile.XXXXXX)
  trap "rm -f '$modelfile_tmp'" RETURN
  sed "1s|^FROM.*|FROM $BASE_MODEL|" "${SRC_DIR}/Modelfile" > "$modelfile_tmp"

  if ! ollama create "$CUSTOM_MODEL" -f "$modelfile_tmp"; then
    echo "❌ Échec de la création du modèle '$CUSTOM_MODEL'." >&2
    exit 1
  fi
  mkdir -p "$(dirname "$IA_STATE_FILE")"
  echo "$BASE_MODEL" > "$IA_STATE_FILE"
  echo "  ✅ Modèle '$CUSTOM_MODEL' créé avec succès ($BASE_MODEL)."
}

install_client_script() {
  echo "→ Installation du client dans ${INSTALL_DIR}..."
  install -m 0755 "${SRC_DIR}/ia.sh" "$SCRIPT_PATH"
}

ensure_alias() {
  sed -i '/alias ia=/d' /etc/bash.bashrc
  echo "alias ia='/usr/local/bin/ia'" >> /etc/bash.bashrc
}

main "$@"
