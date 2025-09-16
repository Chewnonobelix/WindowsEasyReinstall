# Windows Easy Reinstall

Un ensemble d'outils pour automatiser la réinstallation des logiciels sur un PC Windows 11 fraîchement réinstallé.

## 🚀 Fonctionnalités

- **Installation automatique** via winget et chocolatey
- **Configuration personnalisable** via fichiers JSON
- **Support multi-plateformes** : Python et PowerShell
- **Interface utilisateur** interactive et en ligne de commande
- **Gestion des erreurs** robuste avec logs détaillés
- **Rapports d'installation** complets

## 📁 Structure du Projet

```
WindowsEasyReinstall/
├── 📄 software_installer.py              # Script Python principal
├── 📄 SoftwareInstaller.ps1              # Script PowerShell principal
├── 📄 Install-CustomSoftware.ps1         # Script PowerShell personnalisé
├── 📄 Run-SoftwareInstaller.ps1          # Script PowerShell interactif
├── 📄 Run-Installation-Examples.ps1      # Script d'exemples
├── 📄 Install-Requirements.ps1           # Installation des prérequis
├── 📄 software_config_custom.json        # Configuration personnalisée (39 logiciels)
├── 📄 software_config_powershell.json    # Configuration PowerShell standard
├── 📄 software_config.json               # Configuration Python compatible
├── 📄 software_config_example.json       # Exemple de configuration
├── 📄 requirements.txt                   # Dépendances Python
├── 📄 README.md                          # Documentation principale
├── 📄 README-PowerShell.md               # Documentation PowerShell
├── 📄 README-CustomSoftware.md           # Documentation configuration personnalisée
└── 📄 .gitignore                         # Fichiers à ignorer
```

## 🛠️ Installation Rapide

### Méthode 1 : PowerShell (Recommandé)

```powershell
# Installation des prérequis
.\Install-Requirements.ps1

# Installation avec configuration personnalisée
.\Install-CustomSoftware.ps1

# Ou avec script interactif
.\Run-SoftwareInstaller.ps1
```

### Méthode 2 : Python

```bash
# Installation des dépendances
pip install -r requirements.txt

# Exécution du script
python software_installer.py
```

## ⚙️ Configuration

### Fichiers de configuration disponibles

- **`software_config_custom.json`** : Configuration personnalisée complète (39 logiciels)
- **`software_config_powershell.json`** : Configuration PowerShell standard
- **`software_config.json`** : Configuration Python compatible
- **`software_config_example.json`** : Exemple de configuration

### Utilisation avec fichier personnalisé

```powershell
# PowerShell
.\Install-CustomSoftware.ps1 -ConfigFile "ma_config.json"

# Python
python software_installer.py --config ma_config.json
```

## 🎯 Logiciels Inclus

### Navigateurs & Communication
- Mozilla Firefox, Thunderbird, Ferdium
- Discord, Facebook, Instagram

### Jeux & Gaming
- Steam, GOG Galaxy, Epic Games Store, Battle.net
- Nucleus Coop, Guild Wars, Guild Wars 2

### Développement & Programmation
- Visual Studio Code, Cursor, Notepad++
- Python 3, Git, GitKraken, Qt 6
- DBeaver, LaTeX (MiKTeX), TeXmaker

### Productivité & Bureautique
- Microsoft Office, LibreOffice
- Sumatra PDF, Adobe Acrobat Reader

### Multimédia
- VLC Media Player, iTunes, MuseScore

### Utilitaires & Outils
- 7-Zip, WinRAR, DupeGuru
- LD Player, NordPass, NVIDIA App
- Malwarebytes, GIMP

## 📊 Utilisation Avancée

### Scripts PowerShell

```powershell
# Afficher l'aide
.\Install-CustomSoftware.ps1 -Help

# Installation avec logs détaillés
.\Install-CustomSoftware.ps1 -LogLevel Verbose

# Installation automatique (sans confirmation)
.\Install-CustomSoftware.ps1 -SkipConfirmation

# Script d'exemples interactif
.\Run-Installation-Examples.ps1
```

### Scripts Python

```bash
# Installation avec configuration personnalisée
python software_installer.py --config ma_config.json

# Installation avec logs détaillés
python software_installer.py --log-level DEBUG
```

## 🔧 Personnalisation

### Ajouter un nouveau logiciel

Modifiez le fichier JSON de configuration :

```json
{
  "name": "Mon Logiciel",
  "method": "winget",
  "package_id": "Publisher.SoftwareName",
  "category": "Ma Catégorie",
  "description": "Description du logiciel",
  "base_directory": "C:\\Utils\\MonLogiciel",
  "installer": {
    "type": "winget",
    "silent_args": ["--accept-package-agreements", "--accept-source-agreements", "--silent"]
  }
}
```

### Installateurs personnalisés

```json
{
  "name": "Logiciel Personnalisé",
  "method": "custom",
  "base_directory": "C:\\Utils\\MonLogiciel",
  "installer": {
    "type": "custom",
    "download_url": "https://example.com/installer.exe",
    "filename": "installer.exe",
    "silent_args": ["/S"],
    "pre_install_commands": ["echo Préparation..."],
    "post_install_commands": ["echo Installation terminée"]
  }
}
```

## 📝 Logs et Rapports

Le script génère automatiquement :
- **Logs détaillés** : `software_installer.log` ou `custom_software_installer.log`
- **Rapports d'installation** : `installation_report.txt` ou `custom_installation_report.txt`

## 🛡️ Sécurité

- Vérification des privilèges administrateur
- Utilisation de sources officielles uniquement
- Vérification des checksums pour les téléchargements
- Logs détaillés pour traçabilité

## 🤝 Contribution

1. Fork le projet
2. Créez une branche pour votre fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Committez vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Poussez vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## ⚠️ Avertissements

- **Sauvegardez** vos données importantes avant l'exécution
- **Testez** sur une machine virtuelle si possible
- **Vérifiez** la liste des logiciels avant l'installation
- **Surveillez** l'espace disque disponible

## 📞 Support

En cas de problème :
1. Consultez les logs d'installation
2. Vérifiez la configuration JSON
3. Testez l'installation manuelle des logiciels problématiques
4. Vérifiez les prérequis système

---

**Note** : Ce projet est optimisé pour Windows 11 mais fonctionne également sur Windows 10.