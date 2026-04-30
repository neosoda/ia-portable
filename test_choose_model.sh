#!/bin/bash
# Test de choose_model() en isolation

BASE_MODEL="default"

choose_model() {
  if [[ -n "${IA_LOCAL_BASE_MODEL:-}" ]]; then
    return
  fi

  local model_choice="$1"

  case "$model_choice" in
    1)
      BASE_MODEL="qwen2.5:0.5b-instruct"
      ;;
    2)
      BASE_MODEL="qwen2.5-coder:1.5b-instruct"
      ;;
    *)
      BASE_MODEL="qwen2.5:0.5b-instruct"
      ;;
  esac
}

# Test 1: Choix 1 (0.5B)
choose_model "1"
[[ "$BASE_MODEL" == "qwen2.5:0.5b-instruct" ]] && echo "✅ Test 1: Choix 1 OK" || echo "❌ Test 1: FAIL"

# Test 2: Choix 2 (1.5B)
BASE_MODEL="default"
choose_model "2"
[[ "$BASE_MODEL" == "qwen2.5-coder:1.5b-instruct" ]] && echo "✅ Test 2: Choix 2 OK" || echo "❌ Test 2: FAIL"

# Test 3: Choix invalide (défaut 0.5B)
BASE_MODEL="default"
choose_model "3"
[[ "$BASE_MODEL" == "qwen2.5:0.5b-instruct" ]] && echo "✅ Test 3: Choix invalide → défaut OK" || echo "❌ Test 3: FAIL"

# Test 4: Avec IA_LOCAL_BASE_MODEL défini (doit ignorer)
BASE_MODEL="default"
export IA_LOCAL_BASE_MODEL="custom-model"
choose_model "1"
[[ "$BASE_MODEL" == "default" ]] && echo "✅ Test 4: IA_LOCAL_BASE_MODEL respecté" || echo "❌ Test 4: FAIL"

