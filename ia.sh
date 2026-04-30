#!/usr/bin/env bash
# --- IA Shell Assistant (Local Edition via Ollama) ---

set -euo pipefail

API_URL="${IA_LOCAL_API_URL:-http://localhost:11434/api/generate}"
MODEL="${IA_LOCAL_MODEL:-ia-sysadmin}" # Notre modèle custom défini dans le Modelfile

RESPONSE_FILE=""

cleanup() {
  if [[ -n "${RESPONSE_FILE:-}" && -f "$RESPONSE_FILE" ]]; then
    rm -f "$RESPONSE_FILE"
  fi
}

require_binary() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "❌ Dépendance manquante : $bin" >&2
    exit 1
  fi
}

trap cleanup EXIT

require_binary curl
require_binary jq

# ================= Fonctions de sécurité & audit =================

is_dangerous_command() {
  local cmd="$1"
  if echo "$cmd" | grep -qE \
    'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f|rm[[:space:]]+-[a-zA-Z]*f[a-zA-Z]*r|\bdd\b[^|]*\bof=|\bmkfs\b|\bfdisk\b|\bparted\b|\bwipefs\b|\bshred\b|(curl|wget)[^|]*\|[[:space:]]*(bash|sh)\b|:\(\)\{|> /dev/[sh]|chmod[[:space:]]+-?R\b|chmod[[:space:]]+[0-7]*7[0-7][0-7]|\breboot\b|\bpoweroff\b|\bshutdown\b|\biptables[[:space:]]+-F\b|\bufw[[:space:]]+disable\b|\buserdel\b|\bkill[[:space:]]+-9[[:space:]]+1\b'; then
    return 0
  fi
  return 1
}

validate_command_syntax() {
  local cmd="$1"
  if ! bash -n <<< "$cmd" 2>/dev/null; then
    echo "❌ Syntaxe invalide détectée dans la commande générée. Abandon." >&2
    return 1
  fi
  return 0
}

extract_single_line() {
  local raw="$1"
  local line_count
  line_count=$(echo "$raw" | wc -l)
  if [[ $line_count -gt 1 ]]; then
    echo "⚠️  Réponse multi-lignes ($line_count lignes). Seule la première est conservée." >&2
    echo "$raw" | head -1
  else
    echo "$raw"
  fi
}

log_execution() {
  local status="$1"
  local log_file="${HOME}/.ia_history"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf '[%s] [local] PROMPT=%q | CMD=%q | STATUS=%s\n' \
    "$timestamp" "$PROMPT" "$CMD_CLEAN" "$status" >> "$log_file"
}

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
    --)
      shift
      PROMPT="$*"
      break
      ;;
    *)
      # On arrête de parser les flags et on prend tout le reste comme prompt
      PROMPT="$*"
      break 
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
  FULL_PROMPT="${FULL_PROMPT}"$'\n\n'"--- INPUT DATA ---"$'\n'"${PIPE_CONTENT}"
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
if ! curl --silent --show-error --fail --max-time 5 -o /dev/null "${API_URL%/api/generate}"; then
  echo "❌ Erreur : Ollama n'est pas accessible sur localhost:11434." >&2
  exit 1
fi

if ! ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fq "$MODEL"; then
  echo "❌ Erreur : modèle '$MODEL' introuvable dans Ollama." >&2
  echo "   Lance : ollama pull $MODEL" >&2
  exit 1
fi

echo -ne "⏳ Analyse en cours... \r"

# Fonction spinner pour faire patienter
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while kill -0 "$pid" >/dev/null 2>&1; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep "$delay"
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Appel silencieux en background
RESPONSE_FILE=$(mktemp -t ia-local-response.XXXXXX.json)
(curl --silent --show-error --fail-with-body --max-time 30 \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$API_URL" > "$RESPONSE_FILE") &
PID=$!
spinner $PID
if ! wait $PID; then
  printf '\n❌ Erreur : appel API Ollama échoué.\n' >&2
  exit 1
fi

RESPONSE=$(jq -r '.response // empty' "$RESPONSE_FILE")
API_ERROR=$(jq -r '.error // empty' "$RESPONSE_FILE")

if [[ -n "$API_ERROR" ]]; then
  echo "❌ Erreur Ollama : $API_ERROR" >&2
  exit 1
fi

if [[ -z "$RESPONSE" || "$RESPONSE" == "null" ]]; then
  echo "❌ Erreur : L'IA n'a rien renvoyé." >&2
  exit 1
fi

# Nettoyage du markdown résiduel dans la réponse
CMD_CLEAN=$(echo "$RESPONSE" | sed 's/```bash//g;s/```//g' | grep -v '^[[:space:]]*$' | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [[ -z "$CMD_CLEAN" ]]; then
  echo "❌ Erreur : commande vide après nettoyage de la réponse IA." >&2
  exit 1
fi

# ── Validation post-nettoyage ────────────────────────────────────────────────
CMD_CLEAN=$(extract_single_line "$CMD_CLEAN")

if ! validate_command_syntax "$CMD_CLEAN"; then
  exit 1
fi

# ================= Mode Interactif =================
if [[ "$RUN_MODE" == "true" ]]; then
  echo -e "\n💻 \033[1;36mCommande proposée :\033[0m"
  echo -e "   $CMD_CLEAN"

  if is_dangerous_command "$CMD_CLEAN"; then
    echo -e "\n\033[1;31m⚠️  COMMANDE POTENTIELLEMENT DESTRUCTIVE\033[0m"
    echo -e "\033[1;31m   Vérifiez attentivement avant de confirmer.\033[0m"
    read -rp "⚡ Exécuter ? [OUI/N] (tapez OUI en majuscules pour confirmer) " confirm
    if [[ "$confirm" == "OUI" ]]; then
      echo -e "\n🚀 Exécution..."
      bash -c "$CMD_CLEAN"
      log_execution "executed"
    else
      echo "🚫 Annulé."
      log_execution "cancelled"
    fi
  else
    echo ""
    read -rp "⚡ Exécuter ? [o/N] " confirm
    if [[ "$confirm" =~ ^[oO]([uU][iI])?$ ]]; then
      echo -e "\n🚀 Exécution..."
      bash -c "$CMD_CLEAN"
      log_execution "executed"
    else
      echo "🚫 Annulé."
      log_execution "cancelled"
    fi
  fi
else
  echo "$CMD_CLEAN"
fi
