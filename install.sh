#!/usr/bin/env bash
# =====================================================
# Installeur portable — IA Shell Assistant (Mistral)
# Compatible Debian 12/13, Ubuntu 22+, Rocky, etc.
# =====================================================

set -euo pipefail

INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="ia"
SRC_DIR="$(dirname "$(realpath "$0")")"
SCRIPT_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"
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
  apt-get update -qq
  apt-get install -y curl jq >/dev/null
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

ensure_api_key() {
  if [[ -z "${MISTRAL_API_KEY:-}" ]]; then
    read -rp "Entre ta clé API Mistral : " key
    if [[ -n "$key" ]]; then
      echo "export MISTRAL_API_KEY='${key}'" | tee "$PROFILE_FILE" >/dev/null
    else
      echo "⚠️  Clé API non définie. Pense à exporter MISTRAL_API_KEY avant utilisation." >&2
    fi
  fi
}

main "$@"
