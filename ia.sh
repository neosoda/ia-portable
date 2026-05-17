#!/usr/bin/env bash
# IA Shell Assistant - command-first CLI for Bash

set -euo pipefail

API_URL="${IA_LOCAL_API_URL:-http://localhost:11434/api/generate}"
MODEL="${IA_LOCAL_MODEL:-ia-sysadmin}"
CONFIG_FILE="${HOME}/.ia_config"
PIPE_LIMIT="${IA_PIPE_LIMIT:-12000}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

PROVIDER="${PROVIDER:-${IA_PROVIDER:-ollama}}"
MODE="command"
STRICT_MODE=false
PROMPT=""
PIPE_CONTENT=""
RESPONSE_FILE=""
CMD_CLEAN=""
RISK_LEVEL="Faible"
RISK_REASON="lecture ou diagnostic sans modification evidente"

cleanup() {
  if [[ -n "${RESPONSE_FILE:-}" && -f "$RESPONSE_FILE" ]]; then
    rm -f "$RESPONSE_FILE"
  fi
}
trap cleanup EXIT

usage() {
  cat >&2 <<'EOF'
Usage:
  ia "ma demande"                         # commande uniquement
  ia -e "ma demande"                      # commande + explication + risque
  ia -x "ma demande"                      # propose, confirme, execute
  ia -s "ma demande"                      # mode strict/securite renforcee
  ia --provider ollama "ma demande"
  ia --provider openrouter "ma demande"
  cat fichier.log | ia "trouve l'erreur"
EOF
}

require_binary() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Erreur: dependance manquante: $bin" >&2
    exit 1
  fi
}

configure_provider() {
  echo "=== Configuration du fournisseur IA ==="
  echo "1) Local (Ollama)"
  echo "2) Cloud (OpenRouter)"
  read -rp "Choix [1/2] : " provider_choice

  if [[ "$provider_choice" == "2" ]]; then
    read -rp "Cle API OpenRouter : " api_key
    if [[ -z "$api_key" ]]; then
      echo "Erreur: cle API requise." >&2
      exit 1
    fi
    {
      echo 'PROVIDER="openrouter"'
      printf 'OPENROUTER_API_KEY=%q\n' "$api_key"
    } > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo "Fournisseur configure: OpenRouter."
  else
    echo 'PROVIDER="ollama"' > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo "Fournisseur configure: Ollama."
  fi
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--explain)
        MODE="explain"
        shift
        ;;
      -x|--execute|--run)
        MODE="execute"
        shift
        ;;
      -s|--strict)
        STRICT_MODE=true
        shift
        ;;
      --provider)
        if [[ $# -lt 2 ]]; then
          echo "Erreur: --provider attend 'ollama' ou 'openrouter'." >&2
          exit 1
        fi
        PROVIDER="$2"
        shift 2
        ;;
      --provider=*)
        PROVIDER="${1#*=}"
        shift
        ;;
      -c|--config)
        configure_provider
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        PROMPT="$*"
        break
        ;;
      -*)
        echo "Erreur: option inconnue: $1" >&2
        usage
        exit 1
        ;;
      *)
        PROMPT="$*"
        break
        ;;
    esac
  done

  case "$PROVIDER" in
    ollama|openrouter) ;;
    *)
      echo "Erreur: provider invalide: $PROVIDER (attendu: ollama ou openrouter)." >&2
      exit 1
      ;;
  esac
}

read_stdin_context() {
  if [[ ! -t 0 ]]; then
    PIPE_CONTENT=$(head -c "$PIPE_LIMIT" || true)
  fi
}

build_prompt() {
  local os_info="Inconnu"
  [[ -f /etc/os-release ]] && os_info=$(grep -E '^(PRETTY_NAME|NAME)=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')
  local user_id
  user_id=$(id -u)

  local safety_hint="Mode normal: propose la commande Bash la plus simple et directement executable."
  if [[ "$STRICT_MODE" == "true" ]]; then
    safety_hint="Mode strict: privilegie les commandes de lecture/diagnostic, evite sudo, suppression, ecriture systeme et modifications irreversibles."
  fi

  local full_prompt
  full_prompt="[CONTEXT: OS=$os_info, UID=$user_id (0=root)] $safety_hint Request: $PROMPT"

  if [[ -n "$PIPE_CONTENT" ]]; then
    full_prompt="${full_prompt}"$'\n\n'"--- STDIN SAMPLE ---"$'\n'"${PIPE_CONTENT}"$'\n\n'"If useful, produce a command that can read from stdin."
  fi

  printf '%s' "$full_prompt"
}

system_prompt() {
  cat <<'EOF'
Tu es ia, un generateur de commandes Bash pour terminal.

CONTRAT STRICT:
- Reponds par UNE SEULE commande Bash executable, sur UNE SEULE ligne.
- Aucun markdown, aucune explication, aucun commentaire.
- Ne discute jamais avec l'utilisateur.
- Si la demande est ambigue, donne une commande de diagnostic sure.
- Si une entree stdin est fournie, prefere une commande compatible stdin quand c'est pertinent.
- Pour une action destructive incertaine, donne d'abord une commande de verification.
EOF
}

query_openrouter() {
  require_binary curl
  require_binary jq

  if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
    echo "Erreur: cle API OpenRouter non configuree. Lancez 'ia --config' ou exportez OPENROUTER_API_KEY." >&2
    exit 1
  fi

  local user_prompt="$1"
  local models_json payload
  local openrouter_models=(
    "mistralai/mistral-small-3.1-24b-instruct:free"
    "meta-llama/llama-3.3-70b-instruct:free"
    "qwen/qwen3-next-80b-a3b-instruct:free"
    "google/gemma-3-12b-it:free"
    "openai/gpt-oss-20b:free"
    "qwen/qwen3-4b:free"
    "meta-llama/llama-3.2-3b-instruct:free"
  )

  models_json=$(printf '%s\n' "${openrouter_models[@]}" | jq -R . | jq -s .)
  payload=$(jq -n \
    --argjson models "$models_json" \
    --arg system_prompt "$(system_prompt)" \
    --arg user_prompt "$user_prompt" \
    '{
      models: $models,
      messages: [
        {role: "system", content: $system_prompt},
        {role: "user", content: $user_prompt}
      ],
      temperature: 0.1
    }')

  RESPONSE_FILE=$(mktemp -t ia-openrouter-response.XXXXXX.json)
  if ! curl --silent --show-error --fail-with-body --max-time 30 \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "HTTP-Referer: https://github.com/neosoda/ia-portable" \
    -H "X-Title: IA Portable" \
    -d "$payload" \
    "https://openrouter.ai/api/v1/chat/completions" > "$RESPONSE_FILE"; then
    echo "Erreur: appel API OpenRouter echoue." >&2
    cat "$RESPONSE_FILE" >&2
    exit 1
  fi

  local api_error
  api_error=$(jq -r '.error.message // empty' "$RESPONSE_FILE")
  if [[ -n "$api_error" ]]; then
    echo "Erreur OpenRouter: $api_error" >&2
    exit 1
  fi

  jq -r '.choices[0].message.content // empty' "$RESPONSE_FILE"
}

query_ollama() {
  require_binary curl
  require_binary jq
  require_binary ollama

  local user_prompt="$1"
  local payload
  payload=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "$user_prompt" \
    '{
      model: $model,
      prompt: $prompt,
      stream: false,
      options: { temperature: 0.1 }
    }')

  if ! curl --silent --show-error --fail --max-time 5 -o /dev/null "${API_URL%/api/generate}"; then
    echo "Erreur: Ollama n'est pas accessible sur ${API_URL%/api/generate}." >&2
    exit 1
  fi

  if ! ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fq "$MODEL"; then
    echo "Erreur: modele '$MODEL' introuvable dans Ollama." >&2
    echo "Lancez: ollama pull $MODEL" >&2
    exit 1
  fi

  RESPONSE_FILE=$(mktemp -t ia-ollama-response.XXXXXX.json)
  if ! curl --silent --show-error --fail-with-body --max-time 30 \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$API_URL" > "$RESPONSE_FILE"; then
    echo "Erreur: appel API Ollama echoue." >&2
    exit 1
  fi

  local api_error
  api_error=$(jq -r '.error // empty' "$RESPONSE_FILE")
  if [[ -n "$api_error" ]]; then
    echo "Erreur Ollama: $api_error" >&2
    exit 1
  fi

  jq -r '.response // empty' "$RESPONSE_FILE"
}

query_model() {
  local full_prompt="$1"

  if [[ -n "${IA_TEST_RESPONSE:-}" ]]; then
    printf '%s\n' "$IA_TEST_RESPONSE"
    return
  fi

  case "$PROVIDER" in
    openrouter) query_openrouter "$full_prompt" ;;
    ollama) query_ollama "$full_prompt" ;;
  esac
}

clean_command() {
  local raw="$1"
  printf '%s\n' "$raw" \
    | sed 's/```bash//g;s/```//g;s/^[[:space:]]*\$[[:space:]]*//' \
    | grep -v '^[[:space:]]*$' \
    | head -1 \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

validate_command_syntax() {
  local cmd="$1"
  if ! bash -n <<< "$cmd" 2>/dev/null; then
    echo "Erreur: syntaxe Bash invalide dans la commande generee." >&2
    return 1
  fi
}

looks_like_existing_command() {
  local candidate="$1"
  local first
  read -r first _ <<< "$candidate"
  [[ -n "$first" ]] || return 1
  [[ "$candidate" == *" "* ]] || return 1
  command -v "$first" >/dev/null 2>&1 || return 1
  bash -n <<< "$candidate" 2>/dev/null
}

classify_risk() {
  local cmd="$1"
  RISK_LEVEL="Faible"
  RISK_REASON="lecture ou diagnostic sans modification evidente"

  if grep -Eq ':\(\)\{|(\bmkfs\b|\bwipefs\b|\bfdisk\b|\bparted\b)|\bdd\b[^|]*\bof=/dev/|\bkill[[:space:]]+-9[[:space:]]+1\b|\bshutdown\b|\bpoweroff\b|\breboot\b|\buserdel\b|\biptables[[:space:]]+-F\b|\bufw[[:space:]]+disable\b' <<< "$cmd"; then
    RISK_LEVEL="Bloque"
    RISK_REASON="operation systeme critique ou potentiellement irreversible"
    return
  fi

  if grep -Eq '\brm[[:space:]]+-[A-Za-z]*r[A-Za-z]*f|\brm[[:space:]]+-[A-Za-z]*f[A-Za-z]*r|(curl|wget)[^|]*\|[[:space:]]*(bash|sh)\b|\bchmod[[:space:]]+-?R[[:space:]][0-7]*7[0-7][0-7]\b|\bchown[[:space:]]+-?R\b|>[[:space:]]*/dev/[sh]d[a-z]' <<< "$cmd"; then
    RISK_LEVEL="Eleve"
    RISK_REASON="suppression recursive, privilege large ou execution distante"
    return
  fi

  if grep -Eq '\bfind\b.*[[:space:]]-delete([[:space:]]|$)|\brm\b|\bmv\b|\bchmod\b|\bchown\b|\bkill\b|\bsystemctl[[:space:]]+(restart|stop|disable)\b|\b(service)[[:space:]].*(restart|stop)\b|\b(apt|apt-get|dnf|yum|pacman)[[:space:]].*(install|remove|purge|upgrade)\b|\bdocker[[:space:]]+(rm|rmi|compose[[:space:]]+down)\b|\bkubectl[[:space:]]+delete\b|\bsudo\b|(^|[^0-9])>[[:space:]]*[^&]' <<< "$cmd"; then
    RISK_LEVEL="Moyen"
    RISK_REASON="modification de fichiers, services, paquets ou privileges"
  fi
}

strict_refuses_command() {
  local cmd="$1"
  [[ "$RISK_LEVEL" == "Bloque" || "$RISK_LEVEL" == "Eleve" ]] && return 0
  grep -Eq '\bfind\b.*[[:space:]]-delete([[:space:]]|$)|\brm\b|\bsudo\b|\bchmod\b|\bchown\b|(^|[^0-9])>[[:space:]]*[^&]' <<< "$cmd"
}

explain_command() {
  local cmd="$1"
  local path name days

  if [[ "$cmd" =~ ^find[[:space:]]+([^[:space:]]+) ]]; then
    path="${BASH_REMATCH[1]}"
    local path_label="$path"
    [[ "$path" == "." ]] && path_label="le dossier courant"
    local action="liste"
    [[ "$cmd" == *" -delete"* ]] && action="supprime"
    [[ "$cmd" == *" -exec "* ]] && action="applique une action a"
    local detail="les fichiers correspondant aux criteres"
    if [[ "$cmd" =~ -name[[:space:]]+\"?([^\"[:space:]]+)\"? ]]; then
      name="${BASH_REMATCH[1]}"
      detail="les elements nommes $name"
    fi
    if [[ "$cmd" =~ -mtime[[:space:]]+\+([0-9]+) ]]; then
      days="${BASH_REMATCH[1]}"
      detail="$detail de plus de $days jours"
    fi
    printf '%s %s dans %s.\n' "$action" "$detail" "$path_label"
    return
  fi

  case "$cmd" in
    df\ *|df)
      echo "Affiche l'utilisation des systemes de fichiers."
      ;;
    du\ *)
      echo "Calcule l'espace disque utilise par les chemins indiques."
      ;;
    free\ *|free)
      echo "Affiche l'utilisation de la memoire RAM et du swap."
      ;;
    ps\ *|ps)
      echo "Affiche les processus selon les options demandees."
      ;;
    systemctl\ status*)
      echo "Affiche l'etat du service indique."
      ;;
    journalctl\ *)
      echo "Lit les journaux systemd selon les filtres indiques."
      ;;
    grep\ *|rg\ *)
      echo "Recherche du texte selon le motif indique."
      ;;
    tail\ *)
      echo "Affiche la fin d'un fichier ou d'un flux."
      ;;
    mkdir\ *)
      echo "Cree le ou les dossiers indiques."
      ;;
    rm\ *)
      echo "Supprime les fichiers ou dossiers indiques."
      ;;
    cp\ *)
      echo "Copie des fichiers ou dossiers."
      ;;
    mv\ *)
      echo "Deplace ou renomme des fichiers ou dossiers."
      ;;
    chmod\ *)
      echo "Modifie les permissions des fichiers ou dossiers indiques."
      ;;
    chown\ *)
      echo "Modifie le proprietaire des fichiers ou dossiers indiques."
      ;;
    curl\ *|wget\ *)
      echo "Effectue une requete reseau ou telecharge une ressource."
      ;;
    *)
      echo "Execute la commande Bash proposee pour repondre a la demande."
      ;;
  esac
}

print_explained_command() {
  local cmd="$1"
  local explanation
  explanation=$(explain_command "$cmd")

  printf 'Commande proposee :\n\n%s\n\n' "$cmd"
  printf 'Explication :\n%s\n\n' "$explanation"
  printf 'Risque :\n%s - %s.\n' "$RISK_LEVEL" "$RISK_REASON"
}

log_execution() {
  local status="$1"
  local log_file="${HOME}/.ia_history"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf '[%s] [%s] PROMPT=%q | CMD=%q | STATUS=%s\n' \
    "$timestamp" "$PROVIDER" "$PROMPT" "$CMD_CLEAN" "$status" >> "$log_file"
  chmod 600 "$log_file" 2>/dev/null || true
}

execute_with_confirmation() {
  print_explained_command "$CMD_CLEAN"
  printf '\n'

  if [[ "$RISK_LEVEL" == "Bloque" ]]; then
    echo "Execution refusee: risque bloque." >&2
    log_execution "blocked"
    exit 2
  fi

  if [[ -n "${IA_CONFIRM:-}" ]]; then
    confirm="$IA_CONFIRM"
  elif [[ -r /dev/tty ]]; then
    read -rp "Executer ? [y/N] " confirm </dev/tty
  else
    read -rp "Executer ? [y/N] " confirm
  fi
  if [[ "$confirm" =~ ^([yY]|[oO]([uU][iI])?)$ ]]; then
    bash -c "$CMD_CLEAN"
    log_execution "executed"
  else
    echo "Annule."
    log_execution "cancelled"
  fi
}

main() {
  parse_args "$@"
  read_stdin_context

  if [[ -z "$PROMPT" && -z "$PIPE_CONTENT" ]]; then
    usage
    exit 1
  fi

  if [[ "$MODE" == "explain" && -n "$PROMPT" && -z "$PIPE_CONTENT" ]] && looks_like_existing_command "$PROMPT"; then
    CMD_CLEAN="$PROMPT"
  else
    local full_prompt response
    full_prompt=$(build_prompt)
    response=$(query_model "$full_prompt")
    CMD_CLEAN=$(clean_command "$response")
  fi

  if [[ -z "$CMD_CLEAN" || "$CMD_CLEAN" == "null" ]]; then
    echo "Erreur: l'IA n'a pas renvoye de commande exploitable." >&2
    exit 1
  fi

  validate_command_syntax "$CMD_CLEAN"
  classify_risk "$CMD_CLEAN"

  if [[ "$STRICT_MODE" == "true" ]] && strict_refuses_command "$CMD_CLEAN"; then
    if [[ "$MODE" == "command" ]]; then
      echo "Commande refusee en mode strict: $RISK_LEVEL - $RISK_REASON." >&2
    else
      print_explained_command "$CMD_CLEAN"
      printf '\nMode strict : commande refusee.\n' >&2
    fi
    exit 2
  fi

  case "$MODE" in
    command)
      printf '%s\n' "$CMD_CLEAN"
      ;;
    explain)
      print_explained_command "$CMD_CLEAN"
      ;;
    execute)
      execute_with_confirmation
      ;;
  esac
}

main "$@"
