# 🧠 IA Shell Assistant — Portable Edition (OpenRouter avec fallback)

Assistant Bash orienté SRE/sysadmin pour générer des commandes Linux en langage naturel.
Cette édition utilise OpenRouter (API Chat Completions compatible) avec fallback automatique multi-modèles.

---

## ✅ Ce que fait le projet

- Génère une commande Bash unique (sans markdown).
- Injecte un contexte système minimal (OS + UID) dans le prompt.
- Accepte les entrées via pipe (`stdin`) pour analyser logs/code (limite 2000 caractères).
- Propose un mode interactif `-x` avec explication avant exécution.
- Fonctionne avec OpenRouter par défaut **ou** un backend compatible (`OPENROUTER_API_URL`).
- Valide la syntaxe bash et la longueur de la réponse avant toute présentation.
- Détecte les commandes potentiellement destructives et demande une confirmation renforcée (`OUI`).
- Journalise chaque exécution dans `~/.ia_history` (audit trail).

---

## 📦 Installation

```bash
git clone https://github.com/neosoda/ia-portable.git
cd ia-portable
sudo bash install.sh
```

L’installateur :

- installe `curl` + `jq` (apt/dnf/yum),
- copie `ia.sh` vers `/usr/local/bin/ia`,
- ajoute `alias ia='/usr/local/bin/ia'` dans `/etc/bash.bashrc`,
- configure `/usr/local/etc/ia.conf` + chargement global via `/etc/profile.d/ia.sh`.

---

## 🔐 Configuration

Fichier principal : `/usr/local/etc/ia.conf`

Exemple :

```bash
export OPENROUTER_API_KEY="<SECRET>"
# Optionnel
# export OPENROUTER_API_URL="https://openrouter.ai/api/v1/chat/completions"
# export IA_API_TIMEOUT_SECONDS="10"
```

Variables supportées :

- `OPENROUTER_API_KEY` : clé API OpenRouter.
- `OPENROUTER_API_URL` : endpoint API Chat Completions (défaut: `https://openrouter.ai/api/v1/chat/completions`).
- `IA_API_TIMEOUT_SECONDS` : timeout global par requête (défaut: `10`).
- `IA_MAX_RETRIES_PER_MODEL` : nombre de tentatives par modèle sur erreur 429 (défaut: `2`).
- `IA_RETRY_DELAY_SECONDS` : délai entre les tentatives (défaut: `1`).
- `IA_VERBOSE_ERRORS` : affiche la réponse brute de l'API en cas d'erreur (défaut: `0`).

Fallback automatique sur cette liste (ordre fixe) :
1. `mistralai/mistral-small-3.1-24b-instruct:free`
2. `openai/gpt-oss-20b:free`
3. `google/gemma-3-12b-it:free`
4. `z-ai/glm-4.5-air:free`
5. `qwen/qwen3-4b:free`
6. `google/gemma-3-4b-it:free`
7. `meta-llama/llama-3.2-3b-instruct:free`
8. `google/gemma-3n-e4b-it:free`
9. `google/gemma-3n-e2b-it:free`

---

## 💬 Utilisation

### Génération simple

```bash
ia "affiche les connexions SSH actives"
```

### Mode interactif (`-x`)

```bash
ia -x "supprime les fichiers .tmp de plus de 7 jours dans /tmp"
```

Cycle interactif : afficher → expliquer (`?`) → exécuter (`o`) ou annuler.

Pour les commandes détectées comme **destructives** (ex: `rm -rf`, `dd`, `mkfs`…), la confirmation est renforcée : il faut taper `OUI` en majuscules. L'exécution utilise `bash -c` (sous-shell isolé) et non `eval`.

### Analyse via pipe

```bash
tail -n 100 /var/log/syslog | ia "trouve l'erreur principale"
cat script.sh | ia "explique ce script en une phrase"
```

---

## ⚠️ Sécurité et limites

- **La commande générée reste non fiable par défaut** : la relire avant exécution.
- En mode `-x`, l’exécution se fait via `bash -c` (sous-shell isolé) et non `eval`.
- Les commandes destructives (`rm -rf`, `dd of=`, `mkfs`, pipe vers `bash`…) déclenchent une alerte rouge et requièrent `OUI` en majuscules.
- La syntaxe bash est vérifiée (`bash -n`) avant présentation — une commande syntaxiquement invalide est rejetée.
- La clé API est stockée en `0600` (`/usr/local/etc/ia.conf`) pour limiter l’exposition locale du secret.
- En entrée pipe, seules les 2000 premiers caractères sont utilisés.
- Chaque exécution est journalisée dans `~/.ia_history` (timestamp, prompt, commande, statut).

### Journal d’audit

```
~/.ia_history
[2026-03-21 14:32:10] PROMPT="affiche les connexions SSH" | CMD="ss -tnp | grep :22" | STATUS=executed
[2026-03-21 14:33:05] PROMPT="supprime les logs nginx" | CMD="rm -rf /var/log/nginx" | STATUS=cancelled
```

---

## 🧰 Désinstallation

```bash
sudo rm -f /usr/local/bin/ia
sudo rm -f /etc/profile.d/ia.sh
sudo sed -i '/alias ia=/d' /etc/bash.bashrc
```

---

## 📁 Structure

```text
ia-portable/
├── install.sh
├── ia.sh
├── Examples.MD
└── Readme.MD
```

---

## 🛠️ Dépendances

- Bash
- `curl`
- `jq`
- `timeout` (coreutils)

---

**Auteur :** Neosoda
**Licence :** MIT
