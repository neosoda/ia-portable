#!/usr/bin/env bash
# --- IA Shell Assistant (Local Edition via Ollama) ---

set -euo pipefail

API_URL="http://localhost:11434/api/generate"
MODEL="ia-sysadmin" # Notre modèle custom défini dans le Modelfile

# ================= Gestion des Arguments =================
RUN_MODE=false
PROMPT=""
PIPE_CONTENT=""

# Détection de l'entrée standard (Pipe)
if [[ ! -t 0 ]]; then
  PIPE_CONTENT=$(timeout 1 cat | head -c 2000)
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -x|--run)
      RUN_MODE=true
      shift
      ;;
    *)
      if [[ -z "$PROMPT" ]]; then
        PROMPT="$1"
      else
        PROMPT="$PROMPT $1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$PROMPT" && -z "$PIPE_CONTENT" ]]; then
  echo "Usage : ia [-x|--run] \"ta question\"" >&2
  exit 1
fi

# ================= Context Injection =================
# Pour aider le petit modèle (Phi), on injecte le contexte DANS le prompt utilisateur
# car le System Prompt est figé dans le Modelfile.

OS_INFO="Inconnu"
[[ -f /etc/os-release ]] && OS_INFO=$(grep -E '^(PRETTY_NAME|NAME)=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')
USER_ID=$(id -u)

FULL_PROMPT="[CONTEXT: OS=$OS_INFO, UID=$USER_ID (0=root)] Request: $PROMPT"

if [[ -n "$PIPE_CONTENT" ]]; then
  FULL_PROMPT="$FULL_PROMPT. Input data: $PIPE_CONTENT"
fi

# ================= Appel API Ollama =================
# Note: On utilise 'generate' (pas 'chat') car on veut du raw completion sur notre modèle custom
# "stream": false est crucial pour avoir un JSON valide à la fin

PAYLOAD=$(jq -n \
  --arg model "$MODEL" \
  --arg prompt "$FULL_PROMPT" \
  '{
    model: $model,
    prompt: $prompt,
    stream: false,
    options: {
      temperature: 0.1
    }
  }')

# Check si Ollama répond
if ! curl -s -f -o /dev/null "http://localhost:11434"; then
  echo "❌ Erreur : Ollama n'est pas accessible sur localhost:11434." >&2
  echo "   Vérifie avec : systemctl status ollama" >&2
  exit 1
fi

RESPONSE=$(curl -s "$API_URL" -d "$PAYLOAD" | jq -r '.response // empty')

if [[ -z "$RESPONSE" || "$RESPONSE" == "null" ]]; then
  echo "❌ Erreur : L'IA n'a rien renvoyé." >&2
  exit 1
fi

# Nettoyage (Phi est parfois bavard malgré le prompt strict)
CMD_CLEAN=$(echo "$RESPONSE" | sed 's/^```bash//;s/^```//;s/```$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# ================= Mode Interactif =================
if [[ "$RUN_MODE" == "true" ]]; then
  echo -e "\n💻 \033[1;36mCommande proposée :\033[0m"
  echo -e "   $CMD_CLEAN"
  echo -e ""
  read -rp "⚡ Exécuter ? [o/N] " confirm
  if [[ "$confirm" =~ ^[oO](ui)?$ ]]; then
    echo -e "\n🚀 Exécution..."
    eval "$CMD_CLEAN"
  else
    echo "🚫 Annulé."
  fi
else
  echo "$CMD_CLEAN"
fi
