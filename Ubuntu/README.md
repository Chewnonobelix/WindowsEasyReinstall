# Script d'installation de paquets Ubuntu

Ce script permet d'installer automatiquement des paquets depuis un fichier de configuration JSON, en essayant différentes méthodes dans l'ordre de priorité suivant :

1. **apt** - Gestionnaire de paquets Ubuntu natif
2. **snap** - Gestionnaire de paquets Snap
3. **Téléchargement direct** - Téléchargement et installation manuelle

## Prérequis

- Ubuntu (ou distribution Debian-based)
- Accès sudo
- `jq` sera installé automatiquement si absent

## Utilisation

```bash
chmod +x install_packages.sh
./install_packages.sh packages_config.json
```

## Format du fichier JSON

Le fichier de configuration doit suivre ce format :

```json
{
  "packages": [
    {
      "name": "nom-du-paquet",
      "description": "Description optionnelle",
      "download_url": "https://example.com/package.deb",
      "install_command": "commande d'installation personnalisée"
    }
  ]
}
```

### Champs du fichier JSON

- **name** (requis) : Nom du paquet à installer
- **description** (optionnel) : Description du paquet
- **download_url** (optionnel) : URL pour téléchargement direct (supporte .deb, .AppImage, .sh)
- **install_command** (optionnel) : Commande shell personnalisée pour l'installation

### Exemples de configuration

#### Paquet simple (apt/snap)
```json
{
  "name": "git",
  "description": "Système de contrôle de version"
}
```

#### Paquet avec téléchargement direct (.deb)
```json
{
  "name": "my-app",
  "download_url": "https://example.com/my-app.deb"
}
```

#### Paquet avec commande d'installation personnalisée
```json
{
  "name": "docker",
  "install_command": "curl -fsSL https://get.docker.com | bash"
}
```

## Fonctionnalités

- ✅ Installation automatique via apt, snap ou téléchargement direct
- ✅ Détection automatique du type de fichier téléchargé (.deb, .AppImage, .sh)
- ✅ Vérification si le paquet est déjà installé
- ✅ Messages colorés pour un meilleur suivi
- ✅ Résumé détaillé à la fin de l'installation
- ✅ Gestion des erreurs robuste

## Notes

- Le script met à jour automatiquement les dépôts apt avant l'installation
- Les paquets déjà installés sont détectés et ignorés
- Les fichiers temporaires sont nettoyés automatiquement
- Le script s'arrête en cas d'erreur critique mais continue pour les autres paquets
