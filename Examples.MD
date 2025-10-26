````markdown
## 💡 Exemples de Prompts

L’assistant IA comprend le langage naturel et renvoie uniquement des **commandes prêtes à exécuter**.  
Voici quelques exemples concrets :

### 🔍 Diagnostic système
```bash
ia "affiche l’utilisation CPU et mémoire"
ia "liste les services systemd actifs"
ia "montre les ports TCP ouverts avec netstat"
ia "analyse la latence réseau vers 8.8.8.8"
````

### 🧰 Maintenance et nettoyage

```bash
ia "nettoie le cache APT et supprime les paquets inutiles"
ia "vide les fichiers journaux de plus de 30 jours"
ia "redémarre nginx et fail2ban"
ia "désactive IPv6 sur Debian"
```

### 🧑‍💻 Gestion utilisateurs et sécurité

```bash
ia "crée un utilisateur admin avec accès sudo"
ia "change le mot de passe root"
ia "ajoute une clé SSH à l’utilisateur neosoda"
ia "bloque les connexions SSH après 5 échecs avec fail2ban"
```

### 🌐 Réseau et web

```bash
ia "vérifie que nginx écoute bien sur le port 80"
ia "redémarre le tunnel Cloudflare"
ia "ajoute un domaine techsentinel.fr au manager Cloudflare"
ia "affiche l’adresse IP publique du serveur"
```

### 🧠 Administration avancée

```bash
ia "sauvegarde /etc/nginx et /etc/fail2ban dans /root/backup"
ia "installe et démarre Docker"
ia "met à jour tous les paquets système sans confirmation"
ia "active le pare-feu ufw et autorise seulement SSH et HTTPS"
```

### 🧪 Outils & audit rapide

```bash
ia "vérifie la température CPU et la vitesse des ventilateurs"
ia "liste les disques et leur utilisation"
ia "montre la version du kernel et du système"
ia "teste la configuration nginx"
```

---

## 🗣️ Astuces de langage

Tu peux formuler naturellement :

```bash
ia "trouve pourquoi nginx ne démarre plus"
ia "prépare un audit rapide du serveur"
ia "affiche toutes les connexions actives au port 22"
```

L’IA adapte la commande automatiquement.
Tu peux aussi préciser :

* **le format** → `ia "donne une commande une-ligne"`
* **le but exact** → `ia "vérifie que fail2ban protège sshd"`
* **le mode** → `ia "commande bash uniquement"` (par défaut)

