#!/usr/bin/env bash
# --- IA Shell Assistant via OpenRouter API (fallback multi-modèles) ---

set -euo pipefail

CONFIG_FILE="/usr/local/etc/ia.conf"

load_api_key_from_config() {
  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    return 0
  fi

  if [[ ! -r "$config_file" ]]; then
    echo "❌ Fichier de configuration non lisible : $config_file" >&2
    echo "   Ajuste les permissions ou exporte OPENROUTER_API_KEY dans l'environnement." >&2
    exit 1
  fi

  local line value
  line=$(awk '
    /^[[:space:]]*(#|$)/ { next }
    {
      row=$0
      sub(/^[[:space:]]*/, "", row)
      sub(/^[[:space:]]*export[[:space:]]+/, "", row)
      if (row ~ /^(OPENROUTER_API_KEY|MISTRAL_API_KEY)[[:space:]]*=/) {
        print row
      }
    }
  ' "$config_file" | tail -n1)

  if [[ -z "${line:-}" ]]; then
    return 0
  fi

  value="${line#*=}"
  value=$(printf "%s" "$value" | sed -E "s/^[[:space:]]+//; s/[[:space:]]+$//")
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"

  if [[ -n "$value" ]]; then
    API_KEY_FROM_CONFIG="$value"
  fi
}

# ================= Configuration =================
API_KEY_FROM_CONFIG=""
load_api_key_from_config "$CONFIG_FILE"
API_KEY="${OPENROUTER_API_KEY:-${MISTRAL_API_KEY:-${API_KEY_FROM_CONFIG:-}}}"
API_URL="${OPENROUTER_API_URL:-${MISTRAL_API_URL:-https://openrouter.ai/api/v1/chat/completions}}"
REQUEST_TIMEOUT_SECONDS="${IA_API_TIMEOUT_SECONDS:-10}"
VERBOSE_ERRORS="${IA_VERBOSE_ERRORS:-0}"
declare -a MODELS=(
  "mistralai/mistral-small-3.1-24b-instruct:free"
  "openai/gpt-oss-20b:free"
  "google/gemma-3-12b-it:free"
  "z-ai/glm-4.5-air:free"
  "qwen/qwen3-4b:free"
  "google/gemma-3-4b-it:free"
  "meta-llama/llama-3.2-3b-instruct:free"
  "google/gemma-3n-e4b-it:free"
  "google/gemma-3n-e2b-it:free"
)
MAX_RETRIES_PER_MODEL="${IA_MAX_RETRIES_PER_MODEL:-2}"
RETRY_DELAY_SECONDS="${IA_RETRY_DELAY_SECONDS:-1}"

# ================= Gestion des Arguments & Pipe =================
RUN_MODE=false
PROMPT=""
PIPE_CONTENT=""

# Détection de l'entrée standard (Pipe)
if [[ ! -t 0 ]]; then
  # On lit stdin (limité à 2000 caractères pour ne pas exploser le token limit)
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
  echo "Usage : cat fichier | ia \"analyse ceci\"" >&2
  exit 1
fi

if [[ -z "$API_KEY" ]]; then
  echo "❌ Clé API manquante pour l'endpoint IA." >&2
  echo "   Configure-la dans /usr/local/etc/ia.conf ou exporte OPENROUTER_API_KEY." >&2
  exit 1
fi

if [[ ! "$API_KEY" =~ ^sk-or-v1- ]]; then
  echo "❌ Clé API invalide : format inattendu pour OPENROUTER_API_KEY." >&2
  echo "   Vérifie /usr/local/etc/ia.conf (syntaxe: OPENROUTER_API_KEY=...) ou la variable d'environnement." >&2
  exit 1
fi

# ================= Smart Context =================
OS_INFO="Inconnu"
[[ -f /etc/os-release ]] && OS_INFO=$(grep -E '^(PRETTY_NAME|NAME)=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')
USER_ID=$(id -u)
CONTEXT_INFO="OS: $OS_INFO | UID: $USER_ID (0=root)"

SYSTEM_PROMPT="Tu es un Expert Système Linux senior.
CONTEXTE TECHNIQUE : $CONTEXT_INFO.

MISSION :
Génère la commande Bash la plus robuste/sécurisée pour la demande utilisateur.

RÈGLES D'OR :
1. SORTIE : Uniquement le code brut. PAS de Markdown, PAS d'explications, PAS de politesse.
2. SÉCURITÉ : Préfère toujours les versions non-destructrices (ex: 'ls' avant 'rm', ou backup avant modif).
3. VARIABLES : Si une info manque (fichier, IP), utilise un placeholder explicite : <FILE_PATH>, <IP_ADDRESS>.
4. FORMAT : Les commandes complexes doivent être chainées (&&) ou pipées (|) sur une seule ligne physique si possible.

Si la demande est impossible ou trop dangereuse sans confirmation, renvoie : \"echo 'ACTION DANGEREUSE : Détaille ta demande'\""

FINAL_PROMPT="$PROMPT"
if [[ -n "$PIPE_CONTENT" ]]; then
  FINAL_PROMPT="$PROMPT\n\n--- INPUT DATA ---\n$PIPE_CONTENT"
fi

# ================= Appel API (Génération) =================
call_api() {
  local model="$1"
  local sys="$2"
  local usr="$3"
  local raw_response
  local curl_status
  local payload
  local request_prompt
  local attempt=1

  if [[ "$model" == google/gemma-* ]]; then
    # Certains providers Gemma refusent totalement le rôle "system".
    request_prompt="$sys\n\n$usr"
    payload=$(jq -n \
      --arg model "$model" \
      --arg content "$request_prompt" \
      '{
        model: $model,
        messages: [
          {role: "user", content: $content}
        ]
      }')
  else
    payload=$(jq -n \
      --arg model "$model" \
      --arg sys "$sys" \
      --arg content "$usr" \
      '{
        model: $model,
        messages: [
          {role: "system", content: $sys},
          {role: "user", content: $content}
        ]
      }')
  fi
  while (( attempt <= MAX_RETRIES_PER_MODEL )); do
    set +e
    raw_response=$(curl --silent --show-error --fail-with-body \
      --connect-timeout "$REQUEST_TIMEOUT_SECONDS" \
      --max-time "$REQUEST_TIMEOUT_SECONDS" \
      "$API_URL" \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      -d "$payload" 2>&1)
    curl_status=$?
    set -e

    if [[ $curl_status -eq 0 ]]; then
      echo "$raw_response" | jq -r '.choices[0].message.content // empty'
      return 0
    fi

    log_model_error "$model" "$curl_status" "$attempt" "$raw_response"
    if [[ "$raw_response" == *'"code":429'* && $attempt -lt MAX_RETRIES_PER_MODEL ]]; then
      sleep "$RETRY_DELAY_SECONDS"
      ((attempt++))
      continue
    fi

    return 1
  done

  return 1
}


extract_json_error_field() {
  local raw="$1"
  local jq_expr="$2"
  local json_part

  json_part=$(printf "%s" "$raw" | sed -n '/^{/,$p')
  if [[ -z "$json_part" ]]; then
    return 0
  fi

  printf "%s" "$json_part" | jq -r "$jq_expr // empty" 2>/dev/null || true
}

log_model_error() {
  local model="$1"
  local curl_status="$2"
  local attempt="$3"
  local raw_response="$4"
  local provider_msg

  if [[ "$VERBOSE_ERRORS" == "1" ]]; then
    echo "❌ Erreur API modèle '$model' ($curl_status) [tentative $attempt/$MAX_RETRIES_PER_MODEL] : ${raw_response}" >&2
    return
  fi

  provider_msg=$(extract_json_error_field "$raw_response" '.error.metadata.raw')

  if [[ "$raw_response" == *'"code":429'* ]]; then
    echo "⚠️ Modèle '$model' temporairement saturé (429)." >&2
    return
  fi

  if [[ -n "$provider_msg" ]]; then
    echo "⚠️ Modèle '$model' indisponible (${curl_status}) : $provider_msg" >&2
    return
  fi

  case "$curl_status" in
    28)
      echo "⚠️ Modèle '$model' indisponible (timeout)." >&2
      ;;
    6|7)
      echo "⚠️ Modèle '$model' indisponible (problème réseau)." >&2
      ;;
    *)
      echo "⚠️ Modèle '$model' indisponible (curl $curl_status)." >&2
      ;;
  esac
}

call_api_with_fallback() {
  local sys="$1"
  local usr="$2"
  local response=""
  local model

  for model in "${MODELS[@]}"; do
    echo "→ Tentative modèle: $model" >&2
    if response=$(call_api "$model" "$sys" "$usr"); then
      if [[ -n "$response" && "$response" != "null" ]]; then
        echo "$response"
        return 0
      fi
      echo "⚠️ Réponse vide du modèle '$model'." >&2
    fi
    echo "↪️ Fallback vers le modèle suivant..." >&2
  done

  return 1
}

set +e
RESPONSE=$(call_api_with_fallback "$SYSTEM_PROMPT" "$FINAL_PROMPT")
fallback_status=$?
set -e

if [[ $fallback_status -ne 0 || -z "$RESPONSE" || "$RESPONSE" == "null" ]]; then
  echo "❌ Erreur : Aucun modèle n'a répondu correctement." >&2
  exit 1
fi

# Nettoyage
CMD_CLEAN=$(echo "$RESPONSE" | sed 's/^```bash//;s/^```//;s/```$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# ================= Mode Interactif & Explain =================
if [[ "$RUN_MODE" == "true" ]]; then
  while true; do
    echo -e "\n💻 \033[1;36mCommande proposée :\033[0m"
    echo -e "   $CMD_CLEAN"
    echo -e ""
    read -rp "⚡ Exécuter ? [o/N/?] (?=expliquer) " confirm

    case "$confirm" in
      [oO]|[oO][uU][iI])
        echo -e "\n🚀 Exécution..."
        eval "$CMD_CLEAN"
        break
        ;;
      "?")
        echo -e "\n🤔 Analyse en cours..."
        EXPLAIN_SYS="Tu es un expert pédagogique. Explique brièvement (2 phrases max) ce que fait cette commande Bash. Sois précis sur les risques."
        EXPLAIN_RESP=$(call_api_with_fallback "$EXPLAIN_SYS" "Explique cette commande : $CMD_CLEAN")
        echo -e "\033[1;33m$EXPLAIN_RESP\033[0m"
        # On boucle pour redemander confirmation après explication
        ;;
      *)
        echo "🚫 Annulé."
        break
        ;;
    esac
  done
else
  # Mode standard
  echo "$CMD_CLEAN"
fi
