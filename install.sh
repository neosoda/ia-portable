#!/usr/bin/env bash
# =====================================================
# Installeur portable — IA Shell Assistant (Mistral)
# Compatible Debian 12/13, Ubuntu 22+, Rocky, etc.
# =====================================================
set -euo pipefail

INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="ia"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"
DEFAULT_LOG_DIR="$HOME/.local/share/ia"

echo "=== Installation de l’assistant IA ==="

if [[ $EUID -ne 0 ]]; then
  echo "❌ Lance ce script avec sudo ou en root."
  exit 1
fi

echo "→ Vérification des dépendances..."
apt-get update -qq
apt-get install -y curl jq >/dev/null

echo "→ Installation dans ${INSTALL_DIR}..."
cp "${SRC_DIR}/ia.sh" "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

if ! grep -q "alias ia=" /etc/bash.bashrc; then
  echo "alias ia='/usr/local/bin/ia'" >> /etc/bash.bashrc
fi

mkdir -p "$DEFAULT_LOG_DIR"

if [[ -z "${MISTRAL_API_KEY:-}" ]]; then
  read -rp "Entre ta clé API Mistral : " key
  echo "export MISTRAL_API_KEY='${key}'" >> /etc/profile.d/ia.sh
fi

echo "✅ Installation terminée !"
echo "Tu peux maintenant exécuter :  ia 'ta question'"
echo "(Log local : ${DEFAULT_LOG_DIR}/ia.log — modifiable via IA_LOG_PATH ou --log-path)"
