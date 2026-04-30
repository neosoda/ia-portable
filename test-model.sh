#!/usr/bin/env bash
# Script de test pour diagnostiquer le problème model_exists

set -euo pipefail

MODEL_NAME="ia-sysadmin"

echo "=== TEST model_exists ==="
echo ""

# Test 1 : ollama list brut
echo "1️⃣  Sortie brute de 'ollama list':"
ollama list
echo ""

# Test 2 : Extraction des noms uniquement
echo "2️⃣  Extraction des noms (NR>1, colonne 1):"
ollama list | awk 'NR>1 {print $1}'
echo ""

# Test 3 : Recherche avec grep -Fx
echo "3️⃣  Recherche avec grep -Fx '$MODEL_NAME':"
if ollama list | awk 'NR>1 {print $1}' | grep -Fx "$MODEL_NAME"; then
  echo "✅ TROUVÉ (grep -Fx)"
else
  echo "❌ PAS TROUVÉ (grep -Fx)"
fi
echo ""

# Test 4 : Recherche avec grep -Fxq (silencieux)
echo "4️⃣  Test avec grep -Fxq (silencieux):"
if ollama list | awk 'NR>1 {print $1}' | grep -Fxq "$MODEL_NAME"; then
  echo "✅ TROUVÉ (grep -Fxq)"
else
  echo "❌ PAS TROUVÉ (grep -Fxq)"
fi
echo ""

# Test 5 : Recherche avec grep -F (sans x, juste substring)
echo "5️⃣  Recherche avec grep -F '$MODEL_NAME' (sans -x):"
if ollama list | awk 'NR>1 {print $1}' | grep -F "$MODEL_NAME"; then
  echo "✅ TROUVÉ (grep -F)"
else
  echo "❌ PAS TROUVÉ (grep -F)"
fi
echo ""

# Test 6 : Recherche avec grep simple
echo "6️⃣  Recherche avec grep '$MODEL_NAME' (simple):"
if ollama list | awk 'NR>1 {print $1}' | grep "$MODEL_NAME"; then
  echo "✅ TROUVÉ (grep simple)"
else
  echo "❌ PAS TROUVÉ (grep simple)"
fi
echo ""

# Test 7 : Recherche avec :latest
echo "7️⃣  Recherche avec grep -Fxq '${MODEL_NAME}:latest':"
if ollama list | awk 'NR>1 {print $1}' | grep -Fxq "${MODEL_NAME}:latest"; then
  echo "✅ TROUVÉ (avec :latest)"
else
  echo "❌ PAS TROUVÉ (avec :latest)"
fi
echo ""

# Test 8 : Fonction originale
echo "8️⃣  Test de la fonction model_exists originale:"
model_exists() {
  local model="$1"
  ollama list | awk 'NR>1 {print $1}' | grep -Fxq "$model"
}

if model_exists "ia-sysadmin"; then
  echo "✅ model_exists('ia-sysadmin') = OK"
else
  echo "❌ model_exists('ia-sysadmin') = FAIL"
fi

if model_exists "ia-sysadmin:latest"; then
  echo "✅ model_exists('ia-sysadmin:latest') = OK"
else
  echo "❌ model_exists('ia-sysadmin:latest') = FAIL"
fi

echo ""
echo "=== FIN TEST ==="
