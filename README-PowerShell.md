# Script de Réinstallation Automatique des Logiciels - Version PowerShell

Ce script PowerShell automatise la réinstallation des logiciels courants sur un PC Windows 11 fraîchement réinstallé. Il utilise winget (Windows Package Manager) et chocolatey pour installer automatiquement une liste prédéfinie de logiciels.

## 🚀 Fonctionnalités

- **Installation automatique** via winget et chocolatey
- **Configuration personnalisable** via fichier JSON
- **Gestion des erreurs** et logs détaillés
- **Rapport d'installation** complet
- **Vérification des privilèges** administrateur
- **Support multi-méthodes** d'installation
- **Interface utilisateur** interactive
- **Installateurs personnalisés** avec téléchargement et commandes

## 📋 Prérequis

- Windows 10/11
- PowerShell 5.1 ou supérieur
- Privilèges administrateur
- Connexion Internet

## 🛠️ Installation

1. **Téléchargez les fichiers** dans un dossier de votre choix
2. **Ouvrez PowerShell en tant qu'administrateur**
3. **Naviguez vers le dossier** contenant les fichiers
4. **Exécutez le script** :

```powershell
# Méthode 1 : Script interactif (recommandé)
.\Run-SoftwareInstaller.ps1

# Méthode 2 : Script direct
.\SoftwareInstaller.ps1

# Méthode 3 : Avec paramètres personnalisés
.\SoftwareInstaller.ps1 -ConfigFile "ma_config.json" -LogLevel Verbose
```

## 📁 Structure des fichiers

```
📦 Projet PowerShell
├── 📄 SoftwareInstaller.ps1              # Script principal
├── 📄 Run-SoftwareInstaller.ps1          # Script interactif
├── 📄 software_config_powershell.json    # Configuration des logiciels
├── 📄 README-PowerShell.md              # Documentation PowerShell
├── 📄 software_installer.log            # Logs (généré automatiquement)
└── 📄 installation_report.txt           # Rapport (généré automatiquement)
```

### Dossiers créés automatiquement

```
📁 C:\Users\$env:USERNAME\Downloads\SoftwareInstaller\
├── 📁 Installers\                 # Installateurs téléchargés
├── 📁 Logs\                      # Logs détaillés
└── 📁 Temp\                      # Fichiers temporaires
```

## ⚙️ Configuration

### Structure de configuration avancée

Le script utilise une structure JSON flexible avec support des dossiers de base et installateurs personnalisés :

```json
{
  "base_directories": {
    "downloads": "C:\\Users\\$env:USERNAME\\Downloads\\SoftwareInstaller",
    "installers": "C:\\Users\\$env:USERNAME\\Downloads\\SoftwareInstaller\\Installers",
    "temp": "C:\\Users\\$env:USERNAME\\AppData\\Local\\Temp\\SoftwareInstaller",
    "logs": "C:\\Users\\$env:USERNAME\\Documents\\SoftwareInstaller\\Logs"
  },
  "software_list": [
    {
      "name": "Nom du logiciel",
      "method": "winget",
      "package_id": "ID.du.package",
      "category": "Catégorie",
      "description": "Description du logiciel",
      "base_directory": "C:\\Program Files\\MonLogiciel",
      "installer": {
        "type": "winget",
        "silent_args": ["--accept-package-agreements", "--accept-source-agreements", "--silent"]
      }
    }
  ]
}
```

### Dossiers de base

Le script crée automatiquement les dossiers suivants :
- **`downloads`** : Dossier principal de téléchargement
- **`installers`** : Dossier pour les installateurs téléchargés
- **`temp`** : Dossier temporaire pour les opérations
- **`logs`** : Dossier pour les logs détaillés

### Méthodes d'installation supportées

- **`winget`** : Windows Package Manager (recommandé)
- **`chocolatey`** : Chocolatey Package Manager
- **`custom`** : Installateurs personnalisés avec téléchargement et commandes

### Installateurs personnalisés

Pour les logiciels nécessitant une installation personnalisée :

```json
{
  "name": "Mon Logiciel",
  "method": "custom",
  "base_directory": "C:\\Program Files\\MonLogiciel",
  "installer": {
    "type": "custom",
    "download_url": "https://example.com/installer.exe",
    "filename": "mon_installer.exe",
    "silent_args": ["/S", "/D=C:\\Program Files\\MonLogiciel"],
    "checksum": "sha256:abc123...",
    "pre_install_commands": [
      "Write-Host 'Préparation...'",
      "New-Item -ItemType Directory -Path 'C:\\Program Files\\MonLogiciel' -Force"
    ],
    "post_install_commands": [
      "Write-Host 'Installation terminée'",
      "New-ItemProperty -Path 'HKLM:\\SOFTWARE\\MonLogiciel' -Name 'Installed' -Value 1 -PropertyType DWORD -Force"
    ]
  }
}
```

### Options des installateurs personnalisés

- **`download_url`** : URL de téléchargement de l'installateur
- **`filename`** : Nom du fichier téléchargé
- **`silent_args`** : Arguments pour l'installation silencieuse
- **`checksum`** : Vérification d'intégrité (sha256)
- **`pre_install_commands`** : Commandes PowerShell à exécuter avant l'installation
- **`post_install_commands`** : Commandes PowerShell à exécuter après l'installation

## 🎯 Logiciels inclus par défaut

### Navigateurs
- Google Chrome
- Mozilla Firefox
- Microsoft Edge

### Développement
- Visual Studio Code
- Git
- Python 3.11
- Node.js
- Docker Desktop

### Utilitaires
- 7-Zip
- Notepad++
- Windows Terminal
- PowerToys

### Communication
- Discord
- Slack
- Zoom
- Microsoft Teams

### Productivité
- LibreOffice
- Adobe Acrobat Reader

### Multimédia
- VLC Media Player

### Sécurité
- Malwarebytes

### Graphisme
- GIMP

### Jeux
- Steam

## 📊 Utilisation

### Script interactif (Recommandé)

```powershell
.\Run-SoftwareInstaller.ps1
```

Le script interactif propose un menu avec les options suivantes :
1. Installer tous les logiciels
2. Installer seulement les navigateurs
3. Installer seulement les outils de développement
4. Installer seulement les utilitaires
5. Afficher la liste des logiciels
6. Vérifier les prérequis
7. Quitter

### Script direct

```powershell
# Installation basique
.\SoftwareInstaller.ps1

# Avec configuration personnalisée
.\SoftwareInstaller.ps1 -ConfigFile "ma_config.json"

# Avec niveau de log détaillé
.\SoftwareInstaller.ps1 -LogLevel Verbose

# Avec tous les paramètres
.\SoftwareInstaller.ps1 -ConfigFile "ma_config.json" -LogLevel Verbose
```

### Paramètres disponibles

- **`-ConfigFile`** : Chemin vers le fichier de configuration JSON
- **`-LogLevel`** : Niveau de log (Verbose, Info, Warning, Error)
- **`-SkipConfirmation`** : Ignore la confirmation avant l'installation (script interactif)

## 📝 Logs et rapports

Le script génère automatiquement :

- **`software_installer.log`** : Logs détaillés de l'installation
- **`installation_report.txt`** : Rapport final avec succès/échecs

### Niveaux de log

- **`Verbose`** : Tous les messages (recommandé pour le débogage)
- **`Info`** : Messages informatifs (défaut)
- **`Warning`** : Avertissements et erreurs
- **`Error`** : Erreurs uniquement

## 🔧 Dépannage

### Erreur de privilèges
```
Ce script doit être exécuté en tant qu'administrateur!
```
**Solution** : Exécutez PowerShell en tant qu'administrateur

### Erreur d'exécution de script
```
execution of scripts is disabled on this system
```
**Solution** : Exécutez la commande suivante :
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Winget non trouvé
```
Échec de l'installation de winget
```
**Solution** : Vérifiez votre connexion Internet et réessayez

### Logiciel en échec
```
✗ Nom du logiciel
```
**Solution** : Vérifiez l'ID du package dans la configuration

## 🛡️ Sécurité

- Le script vérifie les privilèges administrateur
- Utilise uniquement des sources officielles (winget, chocolatey)
- Logs détaillés pour traçabilité
- Vérification des checksums pour les téléchargements
- Aucune installation de logiciels malveillants

## 🤝 Contribution

Pour ajouter de nouveaux logiciels :

1. Modifiez `software_config_powershell.json`
2. Ajoutez l'entrée avec le bon `package_id`
3. Testez l'installation

## 📄 Licence

Ce script est fourni "tel quel" sans garantie. Utilisez-le à vos propres risques.

## ⚠️ Avertissements

- **Sauvegardez** vos données importantes avant l'exécution
- **Testez** sur une machine virtuelle si possible
- **Vérifiez** la liste des logiciels avant l'installation
- **Surveillez** l'espace disque disponible

## 🔄 Mise à jour

Pour mettre à jour le script :
1. Sauvegardez votre configuration personnalisée
2. Remplacez les fichiers par les nouvelles versions
3. Restaurez votre configuration

## 🆚 Comparaison Python vs PowerShell

| Fonctionnalité | Python | PowerShell |
|----------------|--------|------------|
| **Interface** | Ligne de commande | Interactive + CLI |
| **Prérequis** | Python 3.7+ | PowerShell 5.1+ |
| **Performance** | Bonne | Excellente |
| **Intégration Windows** | Bonne | Native |
| **Gestion des erreurs** | Bonne | Excellente |
| **Logs** | Fichier | Fichier + Console |
| **Configuration** | JSON | JSON |
| **Installateurs personnalisés** | ✅ | ✅ |
| **Dossiers de base** | ✅ | ✅ |
| **Vérification checksum** | ✅ | ✅ |

---

**Note** : Cette version PowerShell est optimisée pour Windows et offre une meilleure intégration avec l'écosystème Microsoft.
