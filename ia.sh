#!/usr/bin/env bash
# --- IA Shell Assistant via Mistral API ---
# Version étendue avec journalisation locale et mode hors ligne
set -euo pipefail

MODEL="mistral-small-latest"
API_URL="https://api.mistral.ai/v1/chat/completions"
LOG_PATH="${IA_LOG_PATH:-${HOME}/.local/share/ia/ia.log}"
LOCAL_ONLY="false"

usage() {
  cat <<'USAGE'
Usage : ia [options] "ta question"

Options :
  --local-only        Désactive tout appel réseau et signale que les suggestions IA ne sont pas disponibles.
  --log-path <chemin> Définit le fichier de log local (par défaut : $HOME/.local/share/ia/ia.log ou IA_LOG_PATH).
  -h, --help          Affiche cette aide.

Variables d'environnement :
  MISTRAL_API_KEY   Clé API Mistral, requise sauf en mode --local-only.
  IA_LOG_PATH       Chemin de log par défaut si --log-path n'est pas fourni.
USAGE
}

sanitize_multiline() {
  echo "$1" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g'
}

log_entry() {
  local status="$1"; shift
  local content="$(sanitize_multiline "$*")"
  if [[ -n "$LOG_PATH" ]]; then
    mkdir -p "$(dirname "$LOG_PATH")" 2>/dev/null || true
    if touch "$LOG_PATH" 2>/dev/null; then
      printf "[%s] %s | prompt=\"%s\" | %s\n" \
        "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$status" "$PROMPT" "$content" >>"$LOG_PATH"
    else
      echo "⚠️ Impossible d'écrire dans le fichier de log ${LOG_PATH}" >&2
    fi
  fi
}

PROMPT_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local-only)
      LOCAL_ONLY="true"
      shift
      ;;
    --log-path)
      if [[ $# -lt 2 ]]; then
        echo "Argument manquant pour --log-path" >&2
        exit 1
      fi
      LOG_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      PROMPT_ARGS+=("$@")
      break
      ;;
    *)
      PROMPT_ARGS+=("$1")
      shift
      ;;
  esac
done

PROMPT="${PROMPT_ARGS[*]:-}" 

if [[ -z "$PROMPT" ]]; then
  usage
  exit 1
fi

if [[ "$LOCAL_ONLY" == "true" ]]; then
  local_msg="Mode --local-only activé : aucune requête réseau n'est envoyée. Les suggestions IA sont indisponibles."
  echo "$local_msg"
  log_entry "LOCAL_ONLY" "$local_msg"
  exit 0
fi

API_KEY="${MISTRAL_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
  echo "❌ Clé API manquante. Exporte-la via : export MISTRAL_API_KEY='clé'" >&2
  exit 1
fi

read -r -d '' PAYLOAD <<EOF_PAYLOAD
{
  "model": "$MODEL",
  "messages": [
    {"role": "system", "content": "Tu es un assistant Linux expert. Donne uniquement des commandes bash exécutables, sans explications."},
    {"role": "user", "content": "$PROMPT"}
  ]
}
EOF_PAYLOAD

RAW_RESPONSE=$(curl -sS -w '\n%{http_code}' "$API_URL" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD") || {
    log_entry "ERROR" "Échec réseau ou curl"
    echo "❌ Impossible de contacter l'API Mistral" >&2
    exit 1
  }

HTTP_CODE="${RAW_RESPONSE##*$'\n'}"
BODY="${RAW_RESPONSE%$'\n'*}"

if [[ "$HTTP_CODE" != "200" ]]; then
  log_entry "ERROR" "API HTTP $HTTP_CODE"
  echo "❌ Réponse inattendue de l'API (HTTP $HTTP_CODE)" >&2
  exit 1
fi

COMMANDS=$(echo "$BODY" | jq -r '.choices[0].message.content // empty')
if [[ -z "$COMMANDS" || "$COMMANDS" == "null" ]]; then
  log_entry "ERROR" "Réponse API vide"
  echo "❌ Aucune commande générée" >&2
  exit 1
fi

log_entry "SUGGESTION" "$COMMANDS"
echo -e "$COMMANDS"
