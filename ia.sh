#!/usr/bin/env bash
# --- IA Shell Assistant via Mistral API ---
set -euo pipefail

API_KEY="${MISTRAL_API_KEY:-}"
MODEL="mistral-small-latest"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ia"
CACHE_FILE="${CACHE_DIR}/history.jsonl"
QUIET_MODE=false
NOTIFY_THRESHOLD=""
PROMPT=""

usage() {
  cat <<'USAGE'
Usage: ia [-q|--quiet] [-n|--notify <seconds>] "question"

Options:
  -q, --quiet           Réponse concise (mode court).
  -n, --notify <sec>    Avertir si la réponse prend au moins <sec> secondes.
  -h, --help            Affiche cette aide.
USAGE
}

notify_completion() {
  local elapsed="$1"
  printf '\a' >&2
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "IA shell" "Réponse disponible après ${elapsed}s" >/dev/null 2>&1 || true
  fi
  echo "🔔 Notification : réponse disponible (${elapsed}s)." >&2
}

load_from_cache() {
  local prompt="$1"
  [[ -f "$CACHE_FILE" ]] || return 1
  local cached
  cached=$(jq -r --arg q "$prompt" 'select(.prompt==$q) | .response' "$CACHE_FILE" 2>/dev/null | tail -n 1)
  [[ -n "$cached" ]] || return 1
  echo "$cached"
  return 0
}

save_to_cache() {
  local prompt="$1" response="$2"
  mkdir -p "$CACHE_DIR"
  jq -n --arg prompt "$prompt" --arg response "$response" '{prompt:$prompt,response:$response,ts:now}' >> "$CACHE_FILE"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -q|--quiet)
        QUIET_MODE=true
        shift
        ;;
      -n|--notify)
        if [[ -z "${2:-}" || ! ${2:-} =~ ^[0-9]+$ ]]; then
          echo "❌ Utilise -n/--notify avec un nombre de secondes." >&2
          exit 1
        fi
        NOTIFY_THRESHOLD="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "❌ Option inconnue : $1" >&2
        usage
        exit 1
        ;;
      *)
        PROMPT+=" ${1}"
        shift
        ;;
    esac
  done

  # Récupère le reste en tant que prompt si passé après --
  if [[ $# -gt 0 ]]; then
    PROMPT+=" $*"
  fi
  PROMPT="${PROMPT# }"
}

main() {
  parse_args "$@"

  if [[ -z "$API_KEY" ]]; then
    echo "❌ Clé API manquante. Exporte-la via : export MISTRAL_API_KEY='clé'" >&2
    exit 1
  fi

  if [[ -z "$PROMPT" ]]; then
    usage
    exit 1
  fi

  local cached
  if cached=$(load_from_cache "$PROMPT"); then
    echo "$cached"
    exit 0
  fi

  local start
  start=$(date +%s)

  local system_prompt="Tu es un assistant Linux expert. Donne uniquement des commandes bash exécutables, sans explications."
  if $QUIET_MODE; then
    system_prompt+=" Réponds en une seule ligne avec la commande minimale."
  fi

  local response
  response=$(curl -s https://api.mistral.ai/v1/chat/completions \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"system\",\"content\":\"$system_prompt\"},{\"role\":\"user\",\"content\":\"$PROMPT\"}]}")

  local content
  content=$(echo "$response" | jq -r '.choices[0].message.content // empty')

  if [[ -z "$content" ]]; then
    echo "❌ Impossible de récupérer une réponse depuis l'API." >&2
    exit 1
  fi

  save_to_cache "$PROMPT" "$content"
  echo -e "$content"

  local elapsed
  elapsed=$(( $(date +%s) - start ))
  if [[ -n "$NOTIFY_THRESHOLD" && $elapsed -ge $NOTIFY_THRESHOLD ]]; then
    notify_completion "$elapsed"
  fi
}

main "$@"
