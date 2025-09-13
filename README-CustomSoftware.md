# Installation de Logiciels Personnalisés - Configuration Spéciale

Ce package contient une configuration spécialement conçue pour installer une liste personnalisée de logiciels sur un PC Windows 11 fraîchement réinstallé.

## 🎯 Logiciels Inclus

### Navigateurs & Communication
- **Mozilla Firefox** - Navigateur web open source
- **Mozilla Thunderbird** - Client de messagerie électronique
- **Ferdium** - Client de messagerie et réseaux sociaux
- **Discord** - Plateforme de communication
- **Facebook** - Application Facebook (via Microsoft Store)
- **Instagram** - Application Instagram (via Microsoft Store)

### Jeux & Gaming
- **Steam** - Plateforme de jeux Steam
- **GOG Galaxy** - Launcher GOG Galaxy
- **Epic Games Store** - Launcher Epic Games
- **Battle.net** - Launcher Blizzard Battle.net
- **Nucleus Coop** - Outil pour jouer en local à plusieurs sur un seul PC
- **Guild Wars** - Installation manuelle requise
- **Guild Wars 2** - Installation manuelle requise

### Multimédia
- **VLC Media Player** - Lecteur multimédia universel
- **iTunes** - Lecteur multimédia et gestionnaire de médias Apple
- **MuseScore** - Éditeur de partition musicale

### Développement & Programmation
- **Notepad++** - Éditeur de texte avancé
- **Qt 6** - Framework de développement Qt 6
- **Python 3** - Langage de programmation Python
- **Git** - Système de contrôle de version distribué
- **GitKraken** - Client Git graphique et intuitif
- **Cursor** - Éditeur de code avec IA intégrée
- **DBeaver** - Client de base de données universel
- **LaTeX (MiKTeX)** - Distribution LaTeX complète
- **TeXmaker** - Éditeur LaTeX (TeXstudio comme alternative)

### Productivité & Bureautique
- **Microsoft Office** - Suite bureautique Microsoft Office
- **Sumatra PDF** - Lecteur PDF léger et rapide

### Utilitaires & Outils
- **7-Zip** - Archiveur de fichiers
- **WinRAR** - Archiveur de fichiers RAR
- **DupeGuru** - Outil de détection de fichiers en double
- **LD Player** - Émulateur Android
- **NordPass** - Gestionnaire de mots de passe
- **NVIDIA App** - Application NVIDIA GeForce Experience

### Graphisme & Design
- **Fotor** - Éditeur de photos en ligne

### Logiciels Spécialisés (Installation Manuelle)
- **Plitch** - Plateforme de mods pour jeux
- **Roccat Swarm** - Logiciel de configuration Roccat
- **Turtle Beach Swarm II** - Logiciel de configuration Turtle Beach
- **QSync** - Logiciel de synchronisation QNAP

## 🚀 Installation Rapide

### Méthode 1 : Script PowerShell (Recommandé)

1. **Ouvrez PowerShell en tant qu'administrateur**
2. **Naviguez vers le dossier** contenant les fichiers
3. **Exécutez le script** :

```powershell
.\Install-CustomSoftware.ps1
```

### Méthode 2 : Avec paramètres personnalisés

```powershell
# Afficher l'aide
.\Install-CustomSoftware.ps1 -Help

# Avec configuration personnalisée
.\Install-CustomSoftware.ps1 -ConfigFile "ma_config.json"

# Avec niveau de log détaillé
.\Install-CustomSoftware.ps1 -LogLevel Verbose

# Sans confirmation
.\Install-CustomSoftware.ps1 -SkipConfirmation

# Combinaison de paramètres
.\Install-CustomSoftware.ps1 -ConfigFile "config_dev.json" -LogLevel Verbose -SkipConfirmation
```

### Méthode 3 : Script d'exemples interactif

```powershell
.\Run-Installation-Examples.ps1
```

## 📁 Structure des Fichiers

```
📦 Configuration Personnalisée
├── 📄 software_config_custom.json    # Configuration des logiciels
├── 📄 Install-CustomSoftware.ps1     # Script d'installation
├── 📄 README-CustomSoftware.md       # Documentation
├── 📄 custom_software_installer.log  # Logs (généré automatiquement)
└── 📄 custom_installation_report.txt # Rapport (généré automatiquement)
```

### Dossiers créés automatiquement

```
📁 D:\Utils\                      # Dossier principal des logiciels
├── 📁 Mozilla Firefox\
├── 📁 VLC Media Player\
├── 📁 Steam\
├── 📁 Discord\
├── 📁 Python\
├── 📁 Git\
├── 📁 GitKraken\
└── ... (tous les autres logiciels)

📁 C:\Users\$env:USERNAME\Downloads\SoftwareInstaller\
├── 📁 Installers\                 # Installateurs téléchargés
├── 📁 Logs\                      # Logs détaillés
└── 📁 Temp\                      # Fichiers temporaires
```

## ⚙️ Méthodes d'Installation

### 1. Installation via Winget (Automatique)
La plupart des logiciels sont installés automatiquement via winget :
- Firefox, Thunderbird, VLC, iTunes
- Steam, GOG Galaxy, Epic Games, Battle.net
- Notepad++, Python, Git, GitKraken, Cursor, DBeaver, MuseScore
- Microsoft Office, Sumatra PDF, WinRAR
- DupeGuru, NordPass, NVIDIA App

### 2. Installation Personnalisée (Semi-automatique)
Certains logiciels nécessitent une approche personnalisée :
- **Facebook & Instagram** : Installation via Microsoft Store
- **Plitch, Roccat Swarm, Turtle Beach, QSync** : Téléchargement et installation avec commandes personnalisées

### 3. Installation Manuelle (Recommandée)
Quelques logiciels nécessitent une installation manuelle :
- **Guild Wars & Guild Wars 2** : Téléchargement depuis les sites officiels
- **Fotor** : Installation via le site web officiel

## ⚙️ Paramètres du Script

### Paramètres disponibles

- **`-ConfigFile <fichier>`** : Chemin vers le fichier de configuration JSON (défaut: software_config_custom.json)
- **`-LogLevel <niveau>`** : Niveau de log (Verbose, Info, Warning, Error) (défaut: Info)
- **`-SkipConfirmation`** : Ignore la confirmation avant l'installation
- **`-Help`** : Affiche l'aide détaillée du script

### Fichiers de configuration disponibles

- **`software_config_custom.json`** : Configuration personnalisée complète (39 logiciels)
- **`software_config_powershell.json`** : Configuration PowerShell standard
- **`software_config.json`** : Configuration Python compatible
- **`software_config_example.json`** : Exemple de configuration

### Exemples d'utilisation

```powershell
# Afficher l'aide
.\Install-CustomSoftware.ps1 -Help

# Installation basique
.\Install-CustomSoftware.ps1

# Avec configuration personnalisée
.\Install-CustomSoftware.ps1 -ConfigFile "ma_config.json"

# Avec logs détaillés
.\Install-CustomSoftware.ps1 -LogLevel Verbose

# Installation automatique
.\Install-CustomSoftware.ps1 -SkipConfirmation

# Combinaison de paramètres
.\Install-CustomSoftware.ps1 -ConfigFile "config_dev.json" -LogLevel Verbose -SkipConfirmation
```

### Script d'exemples interactif

```powershell
.\Run-Installation-Examples.ps1
```

## 🔧 Configuration Avancée

### Personnaliser la Liste des Logiciels

Modifiez le fichier `software_config_custom.json` pour :
- Ajouter de nouveaux logiciels
- Modifier les méthodes d'installation
- Changer les dossiers d'installation
- Personnaliser les arguments d'installation

### Exemple d'Ajout de Logiciel

```json
{
  "name": "Mon Nouveau Logiciel",
  "method": "winget",
  "package_id": "Publisher.SoftwareName",
  "category": "Ma Catégorie",
  "description": "Description du logiciel",
  "base_directory": "C:\\Program Files\\MonLogiciel",
  "installer": {
    "type": "winget",
    "silent_args": ["--accept-package-agreements", "--accept-source-agreements", "--silent"]
  }
}
```

## 📊 Rapport d'Installation

Le script génère automatiquement :
- **`custom_software_installer.log`** : Logs détaillés de l'installation
- **`custom_installation_report.txt`** : Rapport final avec succès/échecs

### Exemple de Rapport

```
=== RAPPORT D'INSTALLATION PERSONNALISÉE ===

Date: 2024-01-15 14:30:25

LOGICIELS INSTALLÉS AVEC SUCCÈS:
----------------------------------------
✓ Mozilla Firefox
✓ VLC Media Player
✓ Steam
✓ Notepad++
✓ Python 3
✓ Microsoft Office

LOGICIELS EN ÉCHEC:
----------------------------------------
✗ Guild Wars (Installation manuelle requise)
✗ Guild Wars 2 (Installation manuelle requise)

RÉSUMÉ:
----------------------------------------
Total installé: 6
Total en échec: 2
```

## 🛠️ Dépannage

### Logiciels en Échec

Si certains logiciels échouent à l'installation :

1. **Vérifiez les logs** dans `custom_software_installer.log`
2. **Installez manuellement** les logiciels marqués comme "Installation manuelle requise"
3. **Vérifiez la connexion Internet** pour les téléchargements
4. **Exécutez en tant qu'administrateur** si nécessaire

### Problèmes Courants

#### Winget non trouvé
```
Échec de l'installation de winget
```
**Solution** : Le script installera automatiquement winget

#### Logiciel non trouvé dans winget
```
No package found matching: PackageName
```
**Solution** : Vérifiez l'ID du package ou utilisez une méthode d'installation personnalisée

#### Erreur de privilèges
```
Access is denied
```
**Solution** : Exécutez PowerShell en tant qu'administrateur

## 🎮 Logiciels de Jeux Spéciaux

### Guild Wars & Guild Wars 2
Ces jeux nécessitent une installation manuelle car ils ne sont pas disponibles dans les gestionnaires de paquets :
1. Visitez le site officiel de Guild Wars
2. Téléchargez le client de jeu
3. Suivez les instructions d'installation

### Launchers de Jeux
Les launchers suivants sont installés automatiquement :
- **Steam** : Plateforme principale de jeux
- **GOG Galaxy** : Jeux DRM-free
- **Epic Games Store** : Jeux Epic Games
- **Battle.net** : Jeux Blizzard

## 🔒 Sécurité

- Tous les téléchargements sont vérifiés
- Utilisation de sources officielles uniquement
- Logs détaillés pour traçabilité
- Aucune installation de logiciels malveillants

## 📝 Notes Importantes

1. **Espace disque** : Assurez-vous d'avoir suffisamment d'espace disque (au moins 50 GB)
2. **Connexion Internet** : Une connexion stable est requise pour les téléchargements
3. **Temps d'installation** : L'installation complète peut prendre 30-60 minutes
4. **Redémarrage** : Certains logiciels peuvent nécessiter un redémarrage

## 🤝 Support

En cas de problème :
1. Consultez les logs d'installation
2. Vérifiez la configuration JSON
3. Testez l'installation manuelle des logiciels problématiques
4. Vérifiez les prérequis système

---

**Note** : Cette configuration est optimisée pour une installation complète sur un PC Windows 11 fraîchement réinstallé. Certains logiciels peuvent nécessiter une configuration supplémentaire après l'installation.
