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

Exemples :

```bash
ia "affiche les ports ouverts"
ia "nettoie le cache apt"
ia "crée un utilisateur dev avec sudo"
```

Options supplémentaires :

```bash
ia --local-only "sans réseau, quelles options basiques existe-t-il ?"
ia --log-path /var/log/ia-assistant.log "commande pour vérifier nginx"
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
* Toutes les requêtes passent par HTTPS

---

## 📝 Journalisation & confidentialité

Le script peut consigner localement les interactions pour audit :

* **Données collectées** : question posée (prompt) et commandes suggérées par l’IA.
* **Emplacement par défaut** : `~/.local/share/ia/ia.log`, modifiable via `IA_LOG_PATH` ou l’option `--log-path <chemin>`.
* **Purge** : `> ~/.local/share/ia/ia.log` pour vider le fichier ou suppression pure et simple.
* **Rotation** : ajout d’une règle `logrotate` classique, par exemple :
  ```
  /home/<user>/.local/share/ia/ia.log {
      weekly
      rotate 4
      compress
      missingok
      notifempty
  }
  ```
* **Mode hors ligne** : `--local-only` bloque toute requête réseau et signale les limitations directement dans la réponse.

---

## 🧩 Auteurs & Crédits

**Auteur :** Neosoda
**Version :** v1.1 — 2025-10-26
**Licence :** MIT

```

