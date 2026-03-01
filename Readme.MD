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

Fallback automatique sur cette liste (ordre fixe) :
1. `qwen/qwen-3-4b`
2. `google/gemma-3-12b`
3. `google/gemma-3-4b`
4. `meta-llama/llama-3.2-3b-instruct`
5. `google/gemma-3n-4b`
6. `google/gemma-3n-2b`

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

Cycle interactif : afficher -> expliquer (`?`) -> exécuter (`o`) ou annuler.

### Analyse via pipe

```bash
tail -n 100 /var/log/syslog | ia "trouve l'erreur principale"
cat script.sh | ia "explique ce script en une phrase"
```

---

## ⚠️ Sécurité et limites

- **La commande générée reste non fiable par défaut** : la relire avant exécution.
- En mode `-x`, l’exécution se fait via `eval` dans le shell courant.
- La clé API est stockée en `0600` (`/usr/local/etc/ia.conf`) pour limiter l'exposition locale du secret.
- En entrée pipe, seules les 2000 premières caractères sont utilisées.

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
