````markdown
# 🧠 IA Shell Assistant — Portable Edition

Assistant en ligne de commande pour administrateurs Linux, utilisant l’API **Mistral AI** - https://docs.mistral.ai/api.
Conçu pour être **rapide, autonome et portable**, il s’installe en une seule commande et fonctionne sur tout serveur Debian/Ubuntu.

---

## 🚀 Fonctionnalités

- ⚙️ **Commandes Linux intelligentes** générées par IA (Mistral)
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
````

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

Lors de l’installation, tu peux entrer ta clé API Mistral (commence par `op9k...`).
Sinon, tu peux la définir manuellement plus tard :

```bash
export MISTRAL_API_KEY="ta_cle_api"
```

Pour la rendre permanente :

```bash
echo "export MISTRAL_API_KEY='ta_cle_api'" | sudo tee /etc/profile.d/ia.sh
```

---

## 💬 Utilisation

Simple et rapide :

```bash
ia "affiche les connexions actives SSH"
```

L’assistant renverra uniquement les **commandes bash** exécutables, sans texte inutile.

Options utiles :

```bash
ia -q "question"             # réponse courte / une seule ligne
ia -n 30 "question"          # notification si la réponse prend ≥ 30 s
ia --quiet --notify 60 "..."  # combinaison des deux
```

Exemples :

```bash
ia "affiche les ports ouverts"
ia "nettoie le cache apt"
ia "crée un utilisateur dev avec sudo"
```

Un cache local garde les commandes déjà générées : une question répétée renvoie immédiatement la dernière réponse enregistrée. Les complétions Bash/Zsh proposent automatiquement les questions fréquentes issues de ce cache.

---

## 🧰 Désinstallation

```bash
sudo rm -f /usr/local/bin/ia
sudo rm -f /etc/profile.d/ia.sh
sudo sed -i '/alias ia=/d' /etc/bash.bashrc
```

---

## 🧠 Fonctionnement

Le script appelle directement l’API Mistral :

* Endpoint : `https://api.mistral.ai/v1/chat/completions`
* Modèle : `mistral-small-latest`
* Réponse filtrée pour ne renvoyer **que des commandes**

---

## 📁 Structure

```
ia-portable/
├── install.sh         # installe le script sur n’importe quel serveur
├── ia.sh              # script principal IA Shell Assistant
├── completions/       # complétions bash/zsh basées sur le cache local
└── README.md          # ce fichier
```

---

## 🛠️ Dépendances minimales

* `curl`
* `jq`
* Bash ≥ 5

---

## 🔒 Sécurité

* La clé API est stockée localement dans `/etc/profile.d/ia.sh` (non chiffrée)
* Le script ne conserve **aucune donnée utilisateur**
* Toutes les requêtes passent par HTTPS

---

## 🧩 Auteurs & Crédits

**Auteur :** Neosoda
**Version :** v1.1 — 2025-10-26
**Licence :** MIT

```

