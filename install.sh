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
BASH_COMPLETION_DIR="/usr/share/bash-completion/completions"
ZSH_COMPLETION_DIR="/usr/share/zsh/site-functions"

echo "=== Installation de l’assistant IA ==="

# Vérifie droits root
if [[ $EUID -ne 0 ]]; then
  echo "❌ Lance ce script avec sudo ou en root."
  exit 1
fi

# Installe dépendances
echo "→ Vérification des dépendances..."
apt-get update -qq
apt-get install -y curl jq >/dev/null

# Copie du script
echo "→ Installation dans ${INSTALL_DIR}..."
cp "${SRC_DIR}/ia.sh" "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

# Copie des complétions si possible
if [[ -d "$BASH_COMPLETION_DIR" ]]; then
  cp "${SRC_DIR}/completions/ia.bash" "${BASH_COMPLETION_DIR}/ia"
  echo "→ Auto-complétion bash installée."
else
  echo "ℹ️  Dossier bash-completion introuvable, installe manuellement completions/ia.bash."
fi

if [[ -d "$ZSH_COMPLETION_DIR" ]]; then
  cp "${SRC_DIR}/completions/_ia" "$ZSH_COMPLETION_DIR/"
  echo "→ Auto-complétion zsh installée."
else
  echo "ℹ️  Dossier zsh completions introuvable, installe manuellement completions/_ia."
fi

# Crée un alias global (optionnel)
if ! grep -q "alias ia=" /etc/bash.bashrc; then
  echo "alias ia='/usr/local/bin/ia'" >> /etc/bash.bashrc
fi

# Ajout clé API si absente
if [[ -z "${MISTRAL_API_KEY:-}" ]]; then
  read -rp "Entre ta clé API Mistral : " key
  echo "export MISTRAL_API_KEY='${key}'" >> /etc/profile.d/ia.sh
fi

echo "✅ Installation terminée !"
echo "Tu peux maintenant exécuter :  ia 'ta question'"
