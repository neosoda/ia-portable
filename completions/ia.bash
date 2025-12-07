#!/usr/bin/env bash
# Bash completion for ia command.

_ia_complete() {
  local cur prev cache_file suggestions options
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/ia/history.jsonl"
  options="-q --quiet -n --notify -h --help"

  # If completing the notify value, suggest a few defaults
  if [[ "$prev" == "-n" || "$prev" == "--notify" ]]; then
    COMPREPLY=( $(compgen -W "5 10 30 60 120" -- "$cur") )
    return 0
  fi

  suggestions="$options"
  if [[ -f "$cache_file" ]]; then
    local cached
    cached=$(jq -r '.prompt' "$cache_file" 2>/dev/null | sort -u | tr '\n' ' ')
    suggestions+=" ${cached}"
  fi

  COMPREPLY=( $(compgen -W "$suggestions" -- "$cur") )
  return 0
}

complete -F _ia_complete ia
