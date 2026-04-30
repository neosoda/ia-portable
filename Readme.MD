# 🧠 IA Shell Assistant — Local Edition (Ollama)

Version **100% locale** de l'assistant `ia`, basée sur **Ollama** et **Qwen2.5-Coder 1.5B Instruct**.

Objectif : générer des commandes Bash fiables en langage naturel, sans dépendance cloud, pour environnements sensibles ou isolés.

---

## ✅ Ce que fait ce projet

- **Modèle local uniquement** : Ollama sur `http://localhost:11434` — aucune donnée n'est envoyée en dehors de la machine.
- **Modèle custom optimisé** : `ia-sysadmin` construit depuis le `Modelfile` pour des commandes Bash simples et sûres.
- **Entrée flexible** : prompt direct OU pipe stdin (limite 2000 caractères).
- **Mode interactif** (`-x`) : affichage + confirmation avant exécution.
- **Sécurité renforcée** :
  - Validation syntaxe Bash (`bash -n`) avant présentation.
  - Détection des commandes destructives → confirmation renforcée (`OUI` en majuscules).
  - Journal d'audit dans `~/.ia_history` (timestamp + prompt + commande + statut).
- **Injection de contexte** : OS + UID dans le prompt pour aider le petit modèle.

---

## 📦 Installation

### Prérequis
- Bash 4.x+
- `curl` et `jq`
- Sudo/root pour l'installation

### Installation rapide

```bash
git clone https://github.com/neosoda/ia-portable.git
cd ia-portable
sudo bash install.sh
```

Le script fait :
1. Installe `curl` + `jq` (apt/dnf/yum)
2. Télécharge et installe Ollama (**demande confirmation**)
3. Démarre le service Ollama
4. Télécharge `qwen2.5-coder:1.5b-instruct`
5. Construit le modèle custom `ia-sysadmin`
6. Installe `ia` dans `/usr/local/bin`
7. Configure l'alias global

Durée estimée : **5-10 minutes** (téléchargement + première inférence).

---

## 💬 Utilisation

### Génération simple

```bash
ia "liste les connexions SSH actives"
ia "combien de RAM libre ?"
ia "affiche les 10 plus gros fichiers"
```

### Mode interactif (`-x`)

```bash
ia -x "crée /backup et déplace les logs nginx dedans"
```

Affiche la commande proposée, permet de relire, puis exécute ou annule.

### Analyse via pipe

```bash
tail -100 /var/log/syslog | ia "trouve l'erreur"
cat script_legacy.sh | ia "explique ce script"
journalctl -u nginx -n 50 | ia "résume les erreurs"
```

---

## ⚙️ Configuration

### Variables d'environnement runtime

```bash
# URL API Ollama (défaut: http://localhost:11434/api/generate)
export IA_LOCAL_API_URL="http://localhost:11434/api/generate"

# Modèle utilisé (défaut: ia-sysadmin)
export IA_LOCAL_MODEL="ia-sysadmin"
```

### Variables d'installation

```bash
# Modèle de base Ollama (défaut: qwen2.5-coder:1.5b-instruct)
export IA_LOCAL_BASE_MODEL="qwen2.5-coder:1.5b-instruct"

# Nom du modèle custom (défaut: ia-sysadmin)
export IA_LOCAL_MODEL="ia-sysadmin"

# Timeout au démarrage Ollama (défaut: 30 secondes)
export IA_LOCAL_STARTUP_TIMEOUT_SECONDS="60"
```

---

## ⚠️ Sécurité et limites

| Aspect | Détails |
|--------|---------|
| **Qualité** | Dépend du modèle local (Qwen2.5-Coder 1.5B). Pour du hardware modeste, peut être imprécis sur des requêtes complexes. |
| **Ressources** | ~1-2 Go RAM + CPU pendant l'inférence. Temps de réponse : 5-30 secondes selon le hardware. |
| **Validation humaine** | **Obligatoire** — relire la commande avant exécution (-x ou manuel). |
| **Commandes dangereuses** | `rm -rf`, `dd of=`, `mkfs`, `chmod -R 777`, `kill -9 1`, etc. → alerte rouge + confirmation `OUI` renforcée. |
| **Syntaxe Bash** | Vérifiée (`bash -n`) avant présentation. |
| **Audit** | `~/.ia_history` — timestamp, prompt, commande, statut (executed/cancelled). |

### ⚠️ Recommandations

1. **Toujours relire** avant d'exécuter, même en mode `-x`.
2. **Protéger `~/.ia_history`** si vos prompts contiennent des infos sensibles : `chmod 600 ~/.ia_history`.
3. **Tester sur un lab** avant production.
4. **Ollama doit être en ligne** — vérifier : `ollama list`.

---

## 🔎 Dépannage

### Ollama n'est pas accessible
```bash
curl -s http://localhost:11434
# Ou relancer
systemctl restart ollama
```

### Le modèle `ia-sysadmin` n'existe pas
```bash
ollama list  # Vérifier la présence
ollama create ia-sysadmin -f Modelfile  # Recréer
```

### Réponse lente ou vide
- Vérifier que `qwen2.5-coder:1.5b-instruct` est téléchargé : `ollama list`
- Augmenter le timeout : `export IA_LOCAL_API_URL="..."`
- Vérifier les ressources : `free -h`, `df -h`

### Erreur `Modèle 'ia-sysadmin' introuvable`
```bash
# Depuis le répertoire du projet :
ollama create ia-sysadmin -f Modelfile
```

---

## 🧰 Désinstallation

```bash
sudo rm -f /usr/local/bin/ia
sudo sed -i '/alias ia=/d' /etc/bash.bashrc

# Optionnel : supprimer Ollama
ollama --version  # Vérifier
# Voir https://github.com/ollama/ollama pour la désinstallation

# Garder ou supprimer l'historique :
# rm ~/.ia_history
```

---

## 📁 Structure du projet

```text
.
├── ia.sh              # Client principal (Ollama)
├── install.sh         # Installeur
├── Modelfile          # Définition du modèle custom ia-sysadmin
├── README.md          # Ce fichier
├── Readme-Local.MD    # Ancienne doc (pour référence)
├── LICENSE
├── .gitignore
└── .git/
```

---

## 🚀 Performances attendues

| Opération | Durée |
|-----------|-------|
| Première inférence | 5-10 sec |
| Inférences suivantes | 2-5 sec |
| Validation syntaxe | < 1 sec |
| Mode `-x` (avec confirmation) | 2-5 sec + temps utilisateur |

→ Sur une machine à 4 cores/8GB RAM, les temps sont raisonnables.
→ Sur du ARM/très faible ressource, adapté mais plus lent.

---

## 📝 Exemples avancés

### Avec diagnostic
```bash
ia "diagnose nginx"
# Retourne : systemctl status nginx
```

### Avec contexte pipe
```bash
ps aux | ia "le processus qui utilise le plus de CPU"
# Retourne : ps aux | sort -k3 -nr | head -1
```

### Mode destructif contrôlé
```bash
ia -x "supprime tous les fichiers .log dans /tmp de plus de 30 jours"
# Affiche : find /tmp -name "*.log" -mtime +30 -delete
# Alerte : COMMANDE POTENTIELLEMENT DESTRUCTIVE
# Demande : OUI en majuscules
```

---

## 📄 Licence

MIT — Libre d'utilisation, modification et distribution.

**Auteur :** Neosoda

---

## 🔗 Ressources

- [Ollama Documentation](https://github.com/ollama/ollama)
- [Qwen2.5-Coder Model](https://huggingface.co/Qwen/Qwen2.5-Coder)
- [Bash Security Guidelines](https://mywiki.wooledge.org/)

---

**Dernière mise à jour :** 2026-04-30
