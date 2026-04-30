# IA Shell Assistant — Local Edition (Ollama)

Version **100% locale** de l'assistant `ia`, basée sur **Ollama** et **Qwen2.5**.

Objectif : générer des commandes Bash fiables en langage naturel, sans dépendance cloud, pour environnements sensibles ou isolés.

---

## Ce que fait ce projet

- **Modèle local uniquement** : Ollama sur `http://localhost:11434` — aucune donnée n'est envoyée en dehors de la machine.
- **Choix de modèle à l'installation** : Qwen2.5 0.5B (rapide) ou 1.5B (puissant), sélection interactive.
- **Modèle custom** : `ia-sysadmin` construit depuis le `Modelfile`, recréé automatiquement si le modèle de base change.
- **Entrée flexible** : prompt direct OU pipe stdin (limite 2000 caractères).
- **Mode interactif** (`-x`) : affichage + confirmation avant exécution.
- **Sécurité** :
  - Validation syntaxe Bash (`bash -n`) avant présentation.
  - Détection des commandes destructives → confirmation renforcée (`OUI` en majuscules).
  - Journal d'audit dans `~/.ia_history` (timestamp + prompt + commande + statut).
- **Injection de contexte** : OS + UID dans le prompt pour aider le modèle.

---

## Installation

### Prérequis

- Bash 4.x+
- `curl` et `jq`
- Sudo/root

### Installation rapide

```bash
git clone https://github.com/neosoda/ia-portable.git
cd ia-portable
sudo bash install.sh
```

L'installeur :

1. Demande de choisir un modèle (0.5B rapide ou 1.5B puissant)
2. Installe `curl` + `jq` (apt/dnf/yum)
3. Télécharge et installe Ollama (demande confirmation)
4. Démarre le service Ollama
5. Télécharge le modèle choisi
6. Construit le modèle custom `ia-sysadmin`
7. Installe `ia` dans `/usr/local/bin`
8. Configure l'alias global dans `/etc/bash.bashrc`

**Durée estimée :**
- Qwen 0.5B : 3-5 minutes (340 MB)
- Qwen 1.5B : 8-12 minutes (986 MB)

### Choisir entre Qwen 0.5B et 1.5B

| Aspect | Qwen 0.5B | Qwen 1.5B |
|--------|-----------|-----------|
| **Vitesse** | 1-2 sec | 5-10 sec |
| **Taille** | 340 MB | 986 MB |
| **RAM** | ~500 MB | ~2 GB |
| **Qualité** | Bon pour Bash simple | Meilleur pour requêtes complexes |
| **Cas d'usage** | Production, serveurs légers | Dev, analyses avancées |

**Recommandation :** Choisir **0.5B** par défaut (rapide, léger). Passer à **1.5B** si vous avez besoin d'une meilleure compréhension.

Si vous relancez l'installation avec un modèle différent, `ia-sysadmin` est automatiquement recréé avec la nouvelle base.

---

## Utilisation

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

## Configuration

### Variables runtime

```bash
# URL API Ollama (défaut: http://localhost:11434/api/generate)
export IA_LOCAL_API_URL="http://localhost:11434/api/generate"

# Modèle utilisé (défaut: ia-sysadmin)
export IA_LOCAL_MODEL="ia-sysadmin"
```

### Variables d'installation

```bash
# Modèle de base Ollama (défaut: qwen2.5:0.5b-instruct)
# Si défini, bypasse le menu de sélection interactif
export IA_LOCAL_BASE_MODEL="qwen2.5:0.5b-instruct"

# Timeout au démarrage Ollama (défaut: 30 secondes)
export IA_LOCAL_STARTUP_TIMEOUT_SECONDS="60"
```

---

## Sécurité et limites

| Aspect | Détails |
|--------|---------|
| **Qualité** | Dépend du modèle local. Pour du hardware modeste, peut être imprécis sur des requêtes complexes. |
| **Ressources** | ~1-2 Go RAM + CPU pendant l'inférence. Temps de réponse : 5-30 secondes selon le hardware. |
| **Validation humaine** | Obligatoire — relire la commande avant exécution (`-x` ou manuel). |
| **Commandes dangereuses** | `rm -rf`, `dd of=`, `mkfs`, `chmod -R 777`, `kill -9 1`, etc. → alerte rouge + confirmation `OUI`. |
| **Syntaxe Bash** | Vérifiée (`bash -n`) avant présentation. |
| **Audit** | `~/.ia_history` — timestamp, prompt, commande, statut (executed/cancelled). |

### Limite connue : exécution de commandes LLM

La commande générée est passée à `bash -c` après validation syntaxique. La détection des commandes dangereuses (`is_dangerous_command`) couvre les patterns les plus courants mais **ne peut pas couvrir tous les cas** : une commande syntaxiquement valide et hors-liste peut être destructive.

**Toujours relire** la commande avant de confirmer, même en mode `-x`.

### Recommandations

1. **Toujours relire** avant d'exécuter.
2. **Protéger `~/.ia_history`** si vos prompts contiennent des infos sensibles : `chmod 600 ~/.ia_history`.
3. **Tester sur un lab** avant production.
4. **Ollama doit être en ligne** — vérifier : `ollama list`.
5. **Portabilité** : l'alias global est écrit dans `/etc/bash.bashrc` (Debian/Ubuntu). Sur Fedora/RHEL, ajouter manuellement dans `/etc/bashrc`.

---

## Dépannage

### Ollama n'est pas accessible

```bash
curl -s http://localhost:11434
systemctl restart ollama
```

### Le modèle `ia-sysadmin` n'existe pas

```bash
ollama list
ollama create ia-sysadmin -f Modelfile
```

### Changer de modèle après installation

Relancez simplement `sudo bash install.sh`, choisissez le nouveau modèle. L'installeur détecte le changement et recrée `ia-sysadmin` automatiquement.

### Réponse lente ou vide

- Vérifier que le modèle est téléchargé : `ollama list`
- Vérifier les ressources : `free -h`, `df -h`
- Augmenter le timeout Ollama : `export IA_LOCAL_STARTUP_TIMEOUT_SECONDS=60`

---

## Désinstallation

```bash
sudo rm -f /usr/local/bin/ia
sudo sed -i '/alias ia=/d' /etc/bash.bashrc
sudo rm -f /var/lib/ia/base_model

# Supprimer les modèles Ollama (optionnel)
ollama rm ia-sysadmin
# rm ~/.ia_history
```

---

## Structure du projet

```text
.
├── ia.sh              # Client principal (Ollama)
├── install.sh         # Installeur
├── Modelfile          # Définition du modèle custom ia-sysadmin
├── README.md
├── LICENSE
└── .gitignore
```

---

## Performances attendues

| Opération | Durée |
|-----------|-------|
| Première inférence | 5-10 sec |
| Inférences suivantes | 2-5 sec |
| Validation syntaxe | < 1 sec |
| Mode `-x` (avec confirmation) | 2-5 sec + temps utilisateur |

---

## Exemples avancés

```bash
# Diagnostic nginx
ia "diagnose nginx"
# → systemctl status nginx

# Processus le plus gourmand
ps aux | ia "le processus qui utilise le plus de CPU"
# → ps aux | sort -k3 -nr | head -1

# Suppression contrôlée avec confirmation
ia -x "supprime tous les fichiers .log dans /tmp de plus de 30 jours"
# → find /tmp -name "*.log" -mtime +30 -delete
# Alerte : COMMANDE POTENTIELLEMENT DESTRUCTIVE → OUI requis
```

---

## Licence

MIT — Libre d'utilisation, modification et distribution.

**Auteur :** Neosoda

---

## Ressources

- [Ollama Documentation](https://github.com/ollama/ollama)
- [Qwen2.5-Coder Model](https://huggingface.co/Qwen/Qwen2.5-Coder)
- [Bash Security Guidelines](https://mywiki.wooledge.org/)

---

**Dernière mise à jour :** 2026-04-30
