# 🧠 IA Shell Assistant — Local Edition (Ollama)

Assistant en ligne de commande **100% hors-ligne**, propulsé par [Ollama](https://ollama.com) et le modèle **Phi-2** (2.7B).

Cette version est conçue pour la confidentialité totale et les environnements "air-gapped" (sans internet).

---

## 🚀 Fonctionnalités

- 🔒 **100% Local & Privé** (Aucune donnée ne sort du serveur)
- ⚡ **Modèle custom `ia-sysadmin`** (Optimisé pour Bash via `Modelfile`)
- 🛡️ **Safe-Guards** intégrés (Interdiction `rm -rf`, format strict)
- 🔌 **Compatible Pipes** (`cat log | ia ...`)

---

## 📦 Installation

### Pré-requis
- Un serveur Linux (Debian, Ubuntu, RedHat...)
- ~2 Go de RAM minimum
- ~3 Go d'espace disque (pour le modèle Phi)
- Droits root pour installer le service

### Installation automatique
Ceci installe Ollama, démarre le service, télécharge automatiquement le petit modèle de base (`phi`), construit `ia-sysadmin` et configure la commande `ia`.

```bash
cd ia-local
sudo bash install.sh
```

---

## 💬 Utilisation

Même syntaxe que la version Cloud :

```bash
ia "liste les processus gourmands en RAM"
# output: ps aux --sort=-%mem | head -n 10
```

### Mode Interactif & Exécution
```bash
ia -x "crée un dossier backup et déplace les logs dedans"
```

---

## 🔧 Fonctionnement Technique

1. **Moteur** : Ollama (Service background sur port 11434)
2. **Base** : Modèle `phi` (Microsoft Phi-2, 2.7 milliards de paramètres)
3. **Customisation** :
   Le fichier `Modelfile` définit une couche de "System Prompt" stricte qui transforme Phi en expert Bash mono-maniaque.

L'injection de prompt ressemble à ceci :
```text
[CONTEXT: OS=Debian 12, UID=1000] Request: liste les fichiers
```

---

## ⚠️ Limitations (vs Version Cloud)

* **Intelligence** : Phi-2 (2.7B) est beaucoup moins "intelligent" que Mistral Large/Small. Il peut avoir du mal avec des demandes très complexes ou abstraites.
* **Ressources** : Consomme du CPU/RAM localement pendant la génération.

---

**Auteur :** Neosoda
**Licence :** MIT


## ⚙️ Options avancées

```bash
# Modèle de base Ollama (défaut: phi)
IA_LOCAL_BASE_MODEL=phi

# Nom du modèle final utilisé par ia (défaut: ia-sysadmin)
IA_LOCAL_MODEL=ia-sysadmin
```
