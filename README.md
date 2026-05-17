# IA Portable

Assistant terminal minimal pour transformer une demande en langage naturel en commande Bash exploitable.

Le produit tient dans une idée simple : `ia` ne discute pas. Par défaut, il imprime uniquement la commande.

```bash
ia "trouve les fichiers log de plus de 30 jours"
find . -type f -name "*.log" -mtime +30
```

---

## MVP

```bash
ia "ma demande"                         # donne uniquement la commande
ia -e "ma demande"                      # commande + explication + risque
ia -x "ma demande"                      # propose + confirme + execute
ia -s "ma demande"                      # mode strict / securite renforcee
ia --provider ollama "ma demande"       # force Ollama pour cet appel
ia --provider openrouter "ma demande"   # force OpenRouter pour cet appel
cat fichier.log | ia "trouve l'erreur"  # utilise stdin comme contexte
```

`-e` peut aussi expliquer une commande existante :

```bash
ia -e 'find . -type f -mtime +30 -delete'
```

Sortie :

```text
Commande proposee :

find . -type f -mtime +30 -delete

Explication :
supprime les fichiers correspondant aux criteres de plus de 30 jours dans le dossier courant.

Risque :
Moyen - modification de fichiers, services, paquets ou privileges.
```

---

## Modes

### Commande seule

```bash
ia "liste les connexions SSH actives"
```

Sortie attendue : une seule ligne, sans markdown ni explication.

```bash
ss -tnp | grep ':22'
```

### Explication

```bash
ia -e "supprime les logs nginx de plus de 30 jours"
```

Affiche :

- la commande proposee ;
- une explication courte ;
- un niveau de risque.

### Execution avec confirmation

```bash
ia -x "affiche les fichiers .log de plus de 100 Mo"
```

`ia` affiche la commande, l'explication et le risque, puis demande :

```text
Executer ? [y/N]
```

L'execution est journalisee dans `~/.ia_history`.

### Mode strict

```bash
ia -s "nettoie les vieux logs"
ia -s -x "supprime les fichiers temporaires"
```

Le mode strict pousse le modele vers des commandes de diagnostic et refuse les commandes risquées par defaut :

- suppression (`rm`, `find ... -delete`) ;
- privileges (`sudo`) ;
- permissions/proprietaires (`chmod`, `chown`) ;
- redirections d'ecriture ;
- commandes critiques (`mkfs`, `dd of=/dev/...`, `reboot`, etc.).

---

## Providers

### Ollama

Ollama est le provider local par defaut.

```bash
ia --provider ollama "combien de RAM libre ?"
```

Variables utiles :

```bash
export IA_LOCAL_API_URL="http://localhost:11434/api/generate"
export IA_LOCAL_MODEL="ia-sysadmin"
```

### OpenRouter

OpenRouter permet d'utiliser des modeles cloud avec fallback.

```bash
export OPENROUTER_API_KEY="..."
ia --provider openrouter "diagnostique nginx"
```

Pour enregistrer le provider par defaut :

```bash
ia --config
```

La configuration est stockee dans `~/.ia_config`.

---

## Installation

### Prerequis

- Bash 4.x+
- `curl`
- `jq`
- `sudo` ou root pour l'installation globale

### Installation rapide

```bash
git clone https://github.com/neosoda/ia-portable.git
cd ia-portable
sudo bash install.sh
```

L'installeur :

1. demande le provider par defaut ;
2. installe `curl` et `jq` ;
3. installe Ollama si le mode local est choisi ;
4. construit le modele local `ia-sysadmin` depuis `Modelfile` ;
5. installe la commande `ia` dans `/usr/local/bin`.

---

## Securite

`ia` reste un assistant de terminal, pas un agent autonome.

Garde-fous inclus :

- sortie commande seule par defaut ;
- validation syntaxique avec `bash -n` ;
- classification de risque en `Faible`, `Moyen`, `Eleve` ou `Bloque` ;
- refus des commandes critiques en execution ;
- mode strict pour refuser les actions destructrices ;
- historique local des executions dans `~/.ia_history`.

Les garde-fous ne remplacent pas la relecture humaine. Avant `-x`, relisez toujours la commande proposee.

---

## Exemples

```bash
ia "combien de RAM libre ?"
free -h
```

```bash
ia "les 20 plus gros fichiers ici"
find . -type f -printf '%s %p\n' | sort -nr | head -20
```

```bash
tail -100 /var/log/syslog | ia "trouve les erreurs"
grep -i error
```

```bash
ia -x "redemarre nginx"
```

```bash
ia -s "supprime les logs de plus de 30 jours"
```

En mode strict, `ia` doit privilegier une commande de verification ou refuser la commande si elle reste destructive.

---

## Depannage

### Ollama n'est pas accessible

```bash
curl -s http://localhost:11434
systemctl restart ollama
```

### Le modele `ia-sysadmin` n'existe pas

```bash
ollama list
ollama create ia-sysadmin -f Modelfile
```

### Changer de provider par defaut

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
