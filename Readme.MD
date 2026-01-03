# 🧠 IA Shell Assistant — Portable Edition

Assistant en ligne de commande pour administrateurs Linux, utilisant l’API **Mistral AI** - https://docs.mistral.ai/api.
Conçu pour être **rapide, autonome et portable**, il s’installe en une seule commande et fonctionne sur tout serveur Debian/Ubuntu.

---

## 🚀 Fonctionnalités

- ⚙️ **Commandes Linux intelligentes** générées par IA
- 🔌 **Support des Pipes** : Analyse de logs, refactoring de code...
- 🧠 **Mode Explain** : Explique les commandes dangereuses avant exécution
- 🔒 Aucun service externe permanent requis
- 📦 Installation en local, sans dépendances complexes
- 🔁 Fonctionne aussi sur serveurs distants via SSH
- 🌍 Prévu pour Debian 12/13, Ubuntu 22+, Rocky Linux

---

## 📦 Installation

### 1. Cloner ou copier le dossier
```bash
git clone https://github.com/neosoda/ia-portable.git
cd ia-portable
```

### 2. Lancer l’installeur

```bash
sudo bash install.sh
```

L’installeur :

* installe `curl` et `jq` si nécessaire
* copie le script dans `/usr/local/bin/ia`
* ajoute un alias global `ia`
* configure la clé API Mistral si absente

---

## 🔑 Configuration

Lors de l’installation, tu peux entrer ta clé API Mistral.
Cela créera un fichier de configuration sécurisé (lecture root uniquement) :

```bash
/usr/local/etc/ia.conf
```

Contenu du fichier :

```bash
export MISTRAL_API_KEY="ta_cle_api"
# Optionnel : changer le modèle 
# export MISTRAL_MODEL="mistral-large-latest"

# Optionnel : utiliser un backend local (Ollama, LocalAI)
# export MISTRAL_API_URL="http://localhost:11434/v1/chat/completions"
# export MISTRAL_MODEL="llama3"
```

Pour modifier la configuration, édite simplement ce fichier avec `sudo`.

---

## 💬 Utilisation

### Mode Standard (Sécurisé)
Affiche simplement la commande suggérée par l'IA.

```bash
ia "affiche les connexions actives SSH"
# Résultat : netstat -tnpa | grep 'ssh'
```

### Mode Interactif & Explication
Utilise le flag `-x` pour exécuter ou **comprendre** une commande.

```bash
ia -x "supprime les fichiers tmp vieux de 7 jours"
```
Le script te proposera :
```text
Commande proposée : find /tmp -type f -mtime +7 -delete
⚡ Exécuter ? [o/N/?] (?=expliquer)
```
Si tu tapes `?`, l'IA t'expliquera la commande en détail avant de te redemander confirmation.

### Analyse de contenu (Pipes)
Tu peux envoyer des logs ou du code à l'IA via un pipe `|`.

```bash
# Analyse de logs
tail -n 20 /var/log/syslog | ia "trouve l'erreur critique et propose un fix"

# Explication de code
cat script_bizarre.py | ia "explique ce que fait ce script en 1 phrase"
```

---

## 🧰 Désinstallation

```bash
sudo rm -f /usr/local/bin/ia
sudo rm -f /etc/profile.d/ia.sh
sudo sed -i '/alias ia=/d' /etc/bash.bashrc
```

---

## 🧠 Fonctionnement

### 1. Smart Context
Le script injecte automatiquement le contexte de ton serveur dans le prompt :
- **OS** (ex: "Ubuntu 22.04 LTS")
- **UID** (ex: "0" pour root → commandes sans sudo)

Cela garantit des réponses adaptées (apt vs dnf, sudo vs direct).

### 2. Backend Agnostique
Par défaut configuré sur **Mistral API**, le script est compatible avec tout endpoint compatible OpenAI/Ollama.

* Endpoint défaut : `https://api.mistral.ai/v1/chat/completions`
* Modèle défaut : `mistral-small-latest`

---

## 📁 Structure

```
ia-portable/
├── install.sh         # installe le script sur n’importe quel serveur
├── ia.sh              # script principal IA Shell Assistant
└── Readme.MD          # ce fichier
```

---

## 🛠️ Dépendances minimales

* `curl`
* `jq`
* Bash ≥ 5

---

## 🔒 Sécurité

* La clé API est stockée dans `/usr/local/etc/ia.conf` avec les droits `600` (root only)
* Le script utilise `jq` pour sécuriser l'envoi des données (protection contre injection JSON)
* Aucune donnée utilisateur n'est conservée localement
* Toutes les requêtes passent par HTTPS

---

## 🧩 Auteurs & Crédits

**Auteur :** Neosoda  
**Version :** v2.1 — 2026-01-03  
**Licence :** MIT
