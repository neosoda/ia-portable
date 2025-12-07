#!/usr/bin/env bash
# --- IA Shell Assistant via Mistral API ---

set -euo pipefail

API_KEY="${MISTRAL_API_KEY:-}"
MODEL="mistral-small-latest"
PROMPT="$*"

if [[ -z "$API_KEY" ]]; then
  echo "❌ Clé API manquante. Exporte-la via : export MISTRAL_API_KEY='clé'" >&2
  exit 1
fi

if [[ -z "$PROMPT" ]]; then
  echo "Usage : ia \"ta question\"" >&2
  exit 1
fi

RESPONSE=$(curl -s https://api.mistral.ai/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL\",
    \"messages\": [
      {\"role\": \"system\", \"content\": \"Tu es un assistant Linux expert. Donne uniquement des commandes bash exécutables, sans explications.\"},
      {\"role\": \"user\", \"content\": \"$PROMPT\"}
    ]
  }" | jq -r '.choices[0].message.content')

if [[ -z "$RESPONSE" || "$RESPONSE" == "null" ]]; then
  echo "❌ Impossible de récupérer une commande. Vérifie ta connexion ou ta clé API." >&2
  exit 1
fi

echo -e "$RESPONSE"
