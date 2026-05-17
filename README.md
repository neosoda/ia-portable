# IA Portable

> Natural language in. Bash command out.

`ia` est un assistant terminal minimaliste : vous décrivez ce que vous voulez faire, il renvoie une commande Bash exploitable.

Par défaut, il ne discute pas, n'explique pas, ne met pas de markdown. Il imprime une seule ligne.

```bash
$ ia "trouve les fichiers log de plus de 30 jours"
find . -type f -name "*.log" -mtime +30
```

Avec confirmation :

```bash
$ ia -x "supprime les logs de plus de 30 jours dans /var/log"

Commande proposee :

find /var/log -type f -name "*.log" -mtime +30 -delete

Explication :
supprime les elements nommes *.log de plus de 30 jours dans /var/log.

Risque :
Moyen - modification de fichiers, services, paquets ou privileges.

Executer ? [y/N]
```

---

## Pourquoi

Le terminal est puissant, mais il faut souvent se souvenir de la bonne option, du bon ordre, du bon pipe.

`ia` sert à ça :

- trouver vite la bonne commande ;
- garder une sortie directement utilisable dans le terminal ;
- expliquer seulement quand on le demande ;
- confirmer avant d'executer ;
- fonctionner en local avec Ollama ou via OpenRouter.

---

## Installation

```bash
git clone https://github.com/neosoda/ia-portable.git
cd ia-portable
sudo bash install.sh
```

Prérequis :

- Bash 4+
- `curl`
- `jq`
- `sudo` ou root pour installer globalement la commande `ia`

L'installeur configure le provider, installe les dependances, puis place `ia` dans `/usr/local/bin`.

---

## Utilisation rapide

| Commande | Effet |
| --- | --- |
| `ia "ma demande"` | Renvoie uniquement la commande |
| `ia -e "ma demande"` | Renvoie commande, explication et risque |
| `ia -x "ma demande"` | Propose, confirme, puis execute |
| `ia -s "ma demande"` | Active le mode strict |
| `ia --provider ollama "ma demande"` | Force Ollama pour cet appel |
| `ia --provider openrouter "ma demande"` | Force OpenRouter pour cet appel |
| `cat fichier.log \| ia "trouve l'erreur"` | Utilise stdin comme contexte |

---

## Modes

### Commande seule

Le mode par défaut est fait pour être scriptable et copiable.

```bash
$ ia "combien de RAM libre ?"
free -h
```

```bash
$ ia "les 20 plus gros fichiers ici"
find . -type f -printf '%s %p\n' | sort -nr | head -20
```

### Explication

Utilisez `-e` quand vous voulez comprendre avant d'agir.

```bash
$ ia -e "liste les connexions SSH actives"
```

`-e` peut aussi expliquer une commande existante :

```bash
$ ia -e 'find . -type f -mtime +30 -delete'
```

### Exécution

Utilisez `-x` quand vous voulez laisser `ia` lancer la commande après validation humaine.

```bash
$ ia -x "redemarre nginx"
```

`ia` affiche la commande, son explication, son niveau de risque, puis demande :

```text
Executer ? [y/N]
```

Les executions sont journalisées dans `~/.ia_history`.

### Mode strict

Utilisez `-s` quand vous voulez un comportement plus prudent.

```bash
$ ia -s "nettoie les vieux logs"
```

Le mode strict refuse par défaut les commandes qui touchent aux suppressions, permissions, propriétaires, privileges, redirections d'écriture ou opérations système critiques.

---

## Pipe stdin

`ia` peut utiliser l'entrée standard comme contexte.

```bash
$ tail -100 /var/log/syslog | ia "trouve les erreurs"
grep -i error
```

```bash
$ cat access.log | ia "compte les IP les plus frequentes"
awk '{print $1}' | sort | uniq -c | sort -nr | head
```

La sortie reste une commande exploitable.

---

## Providers

### Ollama local

Ollama est le choix par défaut pour garder les donnees sur la machine.

```bash
ia --provider ollama "diagnostique nginx"
```

Variables utiles :

```bash
export IA_LOCAL_API_URL="http://localhost:11434/api/generate"
export IA_LOCAL_MODEL="ia-sysadmin"
```

### OpenRouter cloud

OpenRouter est utile si vous voulez des réponses plus robustes ou un fallback entre modèles.

```bash
export OPENROUTER_API_KEY="..."
ia --provider openrouter "trouve pourquoi systemd relance ce service"
```

Pour choisir le provider par défaut :

```bash
ia --config
```

La configuration est stockée dans `~/.ia_config`.

---

## Sécurité

`ia` n'est pas un agent autonome. Il propose une commande, et n'execute qu'avec `-x` après confirmation.

Garde-fous inclus :

- sortie commande seule par défaut ;
- validation syntaxique via `bash -n` ;
- classification de risque : `Faible`, `Moyen`, `Eleve`, `Bloque` ;
- refus d'execution des commandes critiques ;
- mode strict pour refuser les actions destructrices ;
- historique local des executions dans `~/.ia_history`.

Le modèle peut se tromper. Relisez toujours avant d'executer.

---

## Exemples

### Diagnostic système

```bash
$ ia "espace disque lisible"
df -h
```

```bash
$ ia "processus qui consomment le plus de CPU"
ps aux --sort=-%cpu | head
```

### Fichiers

```bash
$ ia "trouve les fichiers modifies aujourd'hui"
find . -type f -mtime -1
```

```bash
$ ia -e "archive ce dossier en tar.gz"
```

### Logs

```bash
$ journalctl -u nginx -n 200 | ia "filtre les erreurs"
grep -i error
```

### Prudent par défaut

```bash
$ ia -s "supprime les fichiers temporaires"
```

En mode strict, `ia` doit privilegier une commande de vérification ou refuser la commande si elle reste destructive.

---

## Dépannage

### Ollama ne répond pas

```bash
curl -s http://localhost:11434
systemctl restart ollama
```

### Le modèle local manque

```bash
ollama list
ollama create ia-sysadmin -f Modelfile
```

### Changer de provider

```bash
ia --config
```

---

## Structure

```text
.
├── ia.sh          # client CLI principal
├── install.sh     # installeur
├── Modelfile      # prompt du modele local Ollama
├── README.md
├── LICENSE
└── .gitignore
```

---

## Licence

MIT
