#!/usr/bin/env bash
# --- IA Shell Assistant via Mistral API ---

set -euo pipefail

CONFIG_FILE="/usr/local/etc/ia.conf"

load_api_key_from_config() {
  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    return 0
  fi

  if [[ ! -r "$config_file" ]]; then
    echo "❌ Fichier de configuration non lisible : $config_file" >&2
    echo "   Ajuste les permissions ou exporte MISTRAL_API_KEY dans l'environnement." >&2
    exit 1
  fi

  local line value
  line=$(grep -E '^[[:space:]]*(export[[:space:]]+)?MISTRAL_API_KEY=' "$config_file" | tail -n1 || true)

  if [[ -z "$line" ]]; then
    return 0
  fi

  value="${line#*=}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  API_KEY_FROM_CONFIG="$value"
}

# ================= Configuration =================
API_KEY_FROM_CONFIG=""
load_api_key_from_config "$CONFIG_FILE"
API_KEY="${MISTRAL_API_KEY:-${API_KEY_FROM_CONFIG:-}}"
API_URL="${MISTRAL_API_URL:-https://api.mistral.ai/v1/chat/completions}"
MODEL="${MISTRAL_MODEL:-mistral-small-latest}"

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

if [[ -z "$API_KEY" && "$API_URL" == *"mistral.ai"* ]]; then
  echo "❌ Clé API manquante pour Mistral Cloud." >&2
  echo "   Configure-la dans /usr/local/etc/ia.conf ou exporte MISTRAL_API_KEY." >&2
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
  local sys="$1"
  local usr="$2"
  local raw_response
  local curl_status
  
  local payload=$(jq -n \
    --arg model "$MODEL" \
    --arg sys "$sys" \
    --arg content "$usr" \
    '{
      model: $model,
      messages: [
        {role: "system", content: $sys},
        {role: "user", content: $content}
      ]
    }')

  set +e
  raw_response=$(curl --silent --show-error --fail-with-body "$API_URL" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>&1)
  curl_status=$?
  set -e

  if [[ $curl_status -ne 0 ]]; then
    echo "❌ Erreur API ($curl_status) : ${raw_response}" >&2
    return 1
  fi

  echo "$raw_response" | jq -r '.choices[0].message.content // empty'
}

RESPONSE=$(call_api "$SYSTEM_PROMPT" "$FINAL_PROMPT")

if [[ -z "$RESPONSE" || "$RESPONSE" == "null" ]]; then
  echo "❌ Erreur : Réponse vide de l'IA." >&2
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
        EXPLAIN_RESP=$(call_api "$EXPLAIN_SYS" "Explique cette commande : $CMD_CLEAN")
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
