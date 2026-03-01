#!/usr/bin/env bash
# =====================================================
# Installeur portable — IA Shell Assistant (OpenRouter)
# Compatible Debian 12/13, Ubuntu 22+, Rocky, etc.
# =====================================================

set -euo pipefail

INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="ia"
SRC_DIR="$(dirname "$(realpath "$0")")"
SCRIPT_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"
CONFIG_FILE="/usr/local/etc/ia.conf"
PROFILE_FILE="/etc/profile.d/ia.sh"

main() {
  echo "=== Installation de l’assistant IA ==="

  require_root
  install_dependencies
  install_script
  ensure_alias
  ensure_api_key

  echo "✅ Installation terminée !"
  echo "Tu peux maintenant exécuter :  ia 'ta question'"
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "❌ Lance ce script avec sudo ou en root." >&2
    exit 1
  fi
}

install_dependencies() {
  echo "→ Vérification des dépendances..."
  if command -v apt-get >/dev/null; then
    apt-get update -qq
    apt-get install -y curl jq >/dev/null
  elif command -v dnf >/dev/null; then
    dnf install -y curl jq >/dev/null
  elif command -v yum >/dev/null; then
    yum install -y curl jq >/dev/null
  else
    echo "⚠️  Gestionnaire de paquets inconnu. Assurez-vous d'avoir 'curl' et 'jq' installés manuellement."
  fi
}

install_script() {
  echo "→ Installation dans ${INSTALL_DIR}..."
  install -m 0755 "${SRC_DIR}/ia.sh" "$SCRIPT_PATH"
}

ensure_alias() {
  if ! grep -q "alias ia=" /etc/bash.bashrc; then
    echo "alias ia='/usr/local/bin/ia'" >> /etc/bash.bashrc
  fi
}

extract_api_key_from_file() {
  local file="$1"

  if [[ ! -r "$file" ]]; then
    return 0
  fi

  awk '
    /^[[:space:]]*(#|$)/ { next }
    {
      row=$0
      sub(/^[[:space:]]*/, "", row)
      sub(/^export[[:space:]]+/, "", row)
      if (row ~ /^(OPENROUTER_API_KEY|MISTRAL_API_KEY)[[:space:]]*=/) {
        value=row
        sub(/^[^=]*=/, "", value)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        gsub(/^"|"$/, "", value)
        gsub(/^'\''|'\''$/, "", value)
        if (length(value) > 0) {
          print value
        }
      }
    }
  ' "$file" | tail -n1
}

ensure_api_key() {
  local existing_key=""

  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    existing_key="$OPENROUTER_API_KEY"
  elif [[ -n "${MISTRAL_API_KEY:-}" ]]; then
    existing_key="$MISTRAL_API_KEY"
  elif [[ -f "$CONFIG_FILE" ]]; then
    existing_key="$(extract_api_key_from_file "$CONFIG_FILE")"
  fi

  if [[ -n "$existing_key" ]]; then
    return 0
  fi

  read -rp "Entre ta clé API OpenRouter : " key
  if [[ -z "$key" ]]; then
    echo "⚠️  Clé API non définie. Pense à configurer OPENROUTER_API_KEY manuellement." >&2
    return 0
  fi

  mkdir -p "$(dirname "$CONFIG_FILE")"
  printf "export OPENROUTER_API_KEY='%s'\n" "$key" > "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"

  cat > "$PROFILE_FILE" <<EOF_PROFILE
# shellcheck shell=sh
# Charge la configuration IA pour toutes les sessions utilisateur
[ -r "$CONFIG_FILE" ] && . "$CONFIG_FILE"
EOF_PROFILE
  chmod 644 "$PROFILE_FILE"

  echo "🔒 Clé stockée dans $CONFIG_FILE (permissions 600)"
  echo "🌍 Configuration chargée globalement via $PROFILE_FILE"
}

main "$@"
