# 🧠 IA Shell Assistant — Local Edition (Ollama)

Version locale/offline de l’assistant `ia`, basée sur Ollama.
Objectif : usage sans dépendance cloud pour environnements sensibles ou isolés.

---

## ✅ Ce que fait cette édition

- Utilise Ollama en local (`http://localhost:11434`).
- Déploie un modèle custom `ia-sysadmin` construit depuis `Modelfile`.
- Accepte les entrées via pipe (`stdin`, limite 2000 caractères).
- Fournit un mode interactif `-x` avec confirmation d’exécution.

---

## 📦 Installation

```bash
cd ia-local
sudo bash install.sh
```

L’installateur :

- installe `curl` + `jq`,
- installe Ollama (via script officiel si absent),
- démarre/active le service Ollama,
- télécharge le modèle de base,
- construit le modèle custom,
- installe `ia-local/ia.sh` vers `/usr/local/bin/ia`.

---

## ⚙️ Variables avancées

```bash
# URL de génération Ollama
export IA_LOCAL_API_URL="http://localhost:11434/api/generate"

# Modèle final utilisé par ia
export IA_LOCAL_MODEL="ia-sysadmin"

# Variables d'installation (au moment de sudo bash install.sh)
export IA_LOCAL_BASE_MODEL="phi"
export IA_LOCAL_MODEL="ia-sysadmin"
```

Notes :

- `IA_LOCAL_API_URL` et `IA_LOCAL_MODEL` pilotent le client runtime.
- `IA_LOCAL_BASE_MODEL` sert à l’installation/build du modèle custom.

---

## 💬 Utilisation

### Génération simple

```bash
ia "liste les processus les plus gourmands en RAM"
```

### Mode interactif

```bash
ia -x "crée /root/backup et déplace les logs nginx dedans"
```

### Analyse via pipe

```bash
journalctl -u nginx -n 100 | ia "résume la panne"
cat script_legacy.sh | ia "explique ce script"
```

---

## ⚠️ Limites connues

- La qualité dépend fortement du modèle local choisi.
- CPU/RAM utilisés localement pendant l’inférence.
- La commande proposée doit être validée humainement avant exécution.

---

## 🔎 Dépannage rapide

Vérifier l’API Ollama :

```bash
curl -fsS http://localhost:11434
```

Lister les modèles :

```bash
ollama list
```

Si `ia` échoue, vérifier :

- service Ollama actif,
- modèle `ia-sysadmin` présent,
- `IA_LOCAL_API_URL` correct.

---

## 📁 Structure

```text
ia-local/
├── install.sh
├── ia.sh
├── Modelfile
└── Readme.MD
```

---

**Auteur :** Neosoda
**Licence :** MIT
