#!/usr/bin/env python3
"""
Script de réinstallation automatique des logiciels pour Windows 11
Utilise winget et chocolatey pour installer les logiciels courants
"""

import subprocess
import sys
import json
import os
import time
from pathlib import Path
from typing import List, Dict, Optional
import logging

class SoftwareInstaller:
    def __init__(self):
        self.setup_logging()
        self.installed_software = []
        self.failed_software = []
        self.base_directories = {}
        self.config = {}
        
    def setup_logging(self):
        """Configure le système de logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('software_installer.log', encoding='utf-8'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def run_command(self, command: List[str], timeout: int = 300) -> tuple[bool, str]:
        """Exécute une commande et retourne le succès et la sortie"""
        try:
            self.logger.info(f"Exécution: {' '.join(command)}")
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=timeout,
                shell=True
            )
            
            if result.returncode == 0:
                self.logger.info(f"Commande réussie: {' '.join(command)}")
                return True, result.stdout
            else:
                self.logger.error(f"Erreur dans la commande: {' '.join(command)}")
                self.logger.error(f"Erreur: {result.stderr}")
                return False, result.stderr
                
        except subprocess.TimeoutExpired:
            self.logger.error(f"Timeout pour la commande: {' '.join(command)}")
            return False, "Timeout"
        except Exception as e:
            self.logger.error(f"Exception lors de l'exécution: {e}")
            return False, str(e)
    
    def check_admin_privileges(self) -> bool:
        """Vérifie si le script est exécuté avec les privilèges administrateur"""
        try:
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin()
        except:
            return False
    
    def install_winget(self) -> bool:
        """Installe winget si ce n'est pas déjà fait"""
        self.logger.info("Vérification de winget...")
        success, _ = self.run_command(["winget", "--version"])
        
        if success:
            self.logger.info("Winget est déjà installé")
            return True
        
        self.logger.info("Installation de winget...")
        # Télécharge et installe winget depuis le Microsoft Store
        success, _ = self.run_command([
            "powershell", "-Command", 
            "Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
        ])
        
        if success:
            self.logger.info("Winget installé avec succès")
            return True
        else:
            self.logger.error("Échec de l'installation de winget")
            return False
    
    def install_chocolatey(self) -> bool:
        """Installe chocolatey si ce n'est pas déjà fait"""
        self.logger.info("Vérification de chocolatey...")
        success, _ = self.run_command(["choco", "--version"])
        
        if success:
            self.logger.info("Chocolatey est déjà installé")
            return True
        
        self.logger.info("Installation de chocolatey...")
        success, _ = self.run_command([
            "powershell", "-Command",
            "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
        ])
        
        if success:
            self.logger.info("Chocolatey installé avec succès")
            return True
        else:
            self.logger.error("Échec de l'installation de chocolatey")
            return False
    
    def install_software_winget(self, software_list: List[Dict[str, str]]) -> None:
        """Installe les logiciels via winget"""
        self.logger.info("Installation des logiciels via winget...")
        
        for software in software_list:
            if software.get('method') != 'winget':
                continue
                
            name = software['name']
            package_id = software.get('package_id', name)
            installer_config = software.get('installer', {})
            
            # Utilise les arguments silencieux de la configuration ou les arguments par défaut
            silent_args = installer_config.get('silent_args', [
                "--accept-package-agreements", 
                "--accept-source-agreements", 
                "--silent"
            ])
            
            self.logger.info(f"Installation de {name}...")
            success, output = self.run_command([
                "winget", "install", package_id
            ] + silent_args)
            
            if success:
                self.installed_software.append(name)
                self.logger.info(f"✓ {name} installé avec succès")
                
                # Vérification du dossier de base
                base_directory = software.get('base_directory')
                if base_directory:
                    expanded_base_dir = self.expand_path_variables(base_directory)
                    if os.path.exists(expanded_base_dir):
                        self.logger.info(f"✓ Dossier de base vérifié: {expanded_base_dir}")
                    else:
                        self.logger.warning(f"⚠ Dossier de base non trouvé: {expanded_base_dir}")
            else:
                self.failed_software.append(name)
                self.logger.error(f"✗ Échec de l'installation de {name}")
    
    def install_software_chocolatey(self, software_list: List[Dict[str, str]]) -> None:
        """Installe les logiciels via chocolatey"""
        self.logger.info("Installation des logiciels via chocolatey...")
        
        for software in software_list:
            if software.get('method') != 'chocolatey':
                continue
                
            name = software['name']
            package_id = software.get('package_id', name)
            installer_config = software.get('installer', {})
            
            # Utilise les arguments silencieux de la configuration ou les arguments par défaut
            silent_args = installer_config.get('silent_args', ["-y"])
            
            self.logger.info(f"Installation de {name}...")
            success, output = self.run_command([
                "choco", "install", package_id
            ] + silent_args)
            
            if success:
                self.installed_software.append(name)
                self.logger.info(f"✓ {name} installé avec succès")
                
                # Vérification du dossier de base
                base_directory = software.get('base_directory')
                if base_directory:
                    expanded_base_dir = self.expand_path_variables(base_directory)
                    if os.path.exists(expanded_base_dir):
                        self.logger.info(f"✓ Dossier de base vérifié: {expanded_base_dir}")
                    else:
                        self.logger.warning(f"⚠ Dossier de base non trouvé: {expanded_base_dir}")
            else:
                self.failed_software.append(name)
                self.logger.error(f"✗ Échec de l'installation de {name}")
    
    def download_file(self, url: str, filename: str, download_dir: str) -> bool:
        """Télécharge un fichier depuis une URL"""
        try:
            import urllib.request
            import urllib.parse
            
            download_path = os.path.join(download_dir, filename)
            self.logger.info(f"Téléchargement de {url} vers {download_path}")
            
            urllib.request.urlretrieve(url, download_path)
            self.logger.info(f"✓ Téléchargement réussi: {filename}")
            return True
            
        except Exception as e:
            self.logger.error(f"✗ Erreur téléchargement {filename}: {e}")
            return False
    
    def verify_checksum(self, file_path: str, expected_checksum: str) -> bool:
        """Vérifie la somme de contrôle d'un fichier"""
        try:
            import hashlib
            
            if not expected_checksum.startswith('sha256:'):
                self.logger.warning(f"Type de checksum non supporté: {expected_checksum}")
                return True
            
            expected_hash = expected_checksum[7:]  # Enlever 'sha256:'
            
            with open(file_path, 'rb') as f:
                file_hash = hashlib.sha256(f.read()).hexdigest()
            
            if file_hash.lower() == expected_hash.lower():
                self.logger.info(f"✓ Checksum vérifié: {os.path.basename(file_path)}")
                return True
            else:
                self.logger.error(f"✗ Checksum invalide: {os.path.basename(file_path)}")
                return False
                
        except Exception as e:
            self.logger.error(f"✗ Erreur vérification checksum: {e}")
            return False
    
    def execute_commands(self, commands: List[str], software_name: str) -> bool:
        """Exécute une liste de commandes"""
        for command in commands:
            self.logger.info(f"Exécution commande pour {software_name}: {command}")
            success, output = self.run_command(command.split())
            if not success:
                self.logger.error(f"✗ Commande échouée: {command}")
                return False
        return True
    
    def install_software_custom(self, software: Dict[str, str]) -> bool:
        """Installe un logiciel avec un installateur personnalisé"""
        name = software['name']
        installer_config = software.get('installer', {})
        
        if installer_config.get('type') != 'custom':
            return False
        
        self.logger.info(f"Installation personnalisée de {name}...")
        
        # Récupération des chemins
        installers_dir = self.expand_path_variables(self.base_directories.get('installers', ''))
        temp_dir = self.expand_path_variables(self.base_directories.get('temp', ''))
        
        # Commandes pré-installation
        pre_commands = installer_config.get('pre_install_commands', [])
        if pre_commands:
            self.logger.info(f"Exécution des commandes pré-installation pour {name}")
            if not self.execute_commands(pre_commands, name):
                return False
        
        # Téléchargement si nécessaire
        download_url = installer_config.get('download_url')
        if download_url:
            filename = installer_config.get('filename', os.path.basename(download_url))
            
            if not self.download_file(download_url, filename, installers_dir):
                return False
            
            installer_path = os.path.join(installers_dir, filename)
            
            # Vérification du checksum si fourni
            checksum = installer_config.get('checksum')
            if checksum:
                if not self.verify_checksum(installer_path, checksum):
                    return False
            
            # Installation
            silent_args = installer_config.get('silent_args', [])
            install_command = [installer_path] + silent_args
            
            self.logger.info(f"Installation de {name}...")
            success, output = self.run_command(install_command)
            
            if not success:
                self.logger.error(f"✗ Échec installation {name}")
                return False
        
        # Commandes post-installation
        post_commands = installer_config.get('post_install_commands', [])
        if post_commands:
            self.logger.info(f"Exécution des commandes post-installation pour {name}")
            if not self.execute_commands(post_commands, name):
                return False
        
        # Vérification du dossier de base
        base_directory = software.get('base_directory')
        if base_directory:
            expanded_base_dir = self.expand_path_variables(base_directory)
            if os.path.exists(expanded_base_dir):
                self.logger.info(f"✓ Dossier de base vérifié: {expanded_base_dir}")
            else:
                self.logger.warning(f"⚠ Dossier de base non trouvé: {expanded_base_dir}")
        
        return True
    
    def install_software_direct(self, software_list: List[Dict[str, str]]) -> None:
        """Installe les logiciels via téléchargement direct (legacy)"""
        self.logger.info("Installation des logiciels via téléchargement direct...")
        
        for software in software_list:
            if software.get('method') != 'direct':
                continue
                
            name = software['name']
            download_url = software.get('download_url')
            installer_args = software.get('installer_args', [])
            
            if not download_url:
                self.logger.error(f"URL de téléchargement manquante pour {name}")
                continue
            
            self.logger.info(f"Téléchargement de {name}...")
            # Ici vous pourriez implémenter le téléchargement et l'installation
            # Pour l'instant, on log juste l'information
            self.logger.info(f"URL: {download_url}")
            self.logger.info(f"Arguments: {installer_args}")
    
    def expand_path_variables(self, path: str) -> str:
        """Remplace les variables d'environnement dans un chemin"""
        return os.path.expandvars(path)
    
    def create_directories(self) -> None:
        """Crée les dossiers de base nécessaires"""
        self.logger.info("Création des dossiers de base...")
        
        for dir_name, dir_path in self.base_directories.items():
            expanded_path = self.expand_path_variables(dir_path)
            try:
                os.makedirs(expanded_path, exist_ok=True)
                self.logger.info(f"✓ Dossier créé/vérifié: {expanded_path}")
            except Exception as e:
                self.logger.error(f"✗ Erreur création dossier {dir_name}: {e}")
    
    def load_software_config(self, config_file: str = "software_config.json") -> Dict:
        """Charge la configuration des logiciels depuis un fichier JSON"""
        if not os.path.exists(config_file):
            self.logger.warning(f"Fichier de configuration {config_file} non trouvé, utilisation de la configuration par défaut")
            return self.get_default_config()
        
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)
                self.config = config
                self.base_directories = config.get('base_directories', {})
                return config
        except Exception as e:
            self.logger.error(f"Erreur lors du chargement de la configuration: {e}")
            return self.get_default_config()
    
    def get_default_config(self) -> Dict:
        """Retourne la configuration par défaut"""
        return {
            "base_directories": {
                "downloads": "C:\\Users\\%USERNAME%\\Downloads\\SoftwareInstaller",
                "installers": "C:\\Users\\%USERNAME%\\Downloads\\SoftwareInstaller\\Installers",
                "temp": "C:\\Users\\%USERNAME%\\AppData\\Local\\Temp\\SoftwareInstaller",
                "logs": "C:\\Users\\%USERNAME%\\Documents\\SoftwareInstaller\\Logs"
            },
            "software_list": [
                {"name": "Google Chrome", "method": "winget", "package_id": "Google.Chrome", "base_directory": "C:\\Program Files\\Google\\Chrome"},
                {"name": "Mozilla Firefox", "method": "winget", "package_id": "Mozilla.Firefox", "base_directory": "C:\\Program Files\\Mozilla Firefox"},
                {"name": "Microsoft Edge", "method": "winget", "package_id": "Microsoft.Edge", "base_directory": "C:\\Program Files (x86)\\Microsoft\\Edge\\Application"},
            ]
        }
    
    def generate_report(self) -> None:
        """Génère un rapport d'installation"""
        report_file = "installation_report.txt"
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write("=== RAPPORT D'INSTALLATION ===\n\n")
            f.write(f"Date: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            f.write("LOGICIELS INSTALLÉS AVEC SUCCÈS:\n")
            f.write("-" * 40 + "\n")
            for software in self.installed_software:
                f.write(f"✓ {software}\n")
            
            f.write(f"\nLOGICIELS EN ÉCHEC:\n")
            f.write("-" * 40 + "\n")
            for software in self.failed_software:
                f.write(f"✗ {software}\n")
            
            f.write(f"\nRÉSUMÉ:\n")
            f.write("-" * 40 + "\n")
            f.write(f"Total installé: {len(self.installed_software)}\n")
            f.write(f"Total en échec: {len(self.failed_software)}\n")
        
        self.logger.info(f"Rapport généré: {report_file}")
    
    def run(self, config_file: Optional[str] = None):
        """Lance le processus d'installation"""
        self.logger.info("=== DÉMARRAGE DE L'INSTALLATION DES LOGICIELS ===")
        
        # Vérification des privilèges administrateur
        if not self.check_admin_privileges():
            self.logger.error("Ce script doit être exécuté en tant qu'administrateur!")
            self.logger.info("Fermeture du script...")
            return
        
        # Chargement de la configuration
        config = self.load_software_config(config_file)
        software_list = config.get('software_list', [])
        self.logger.info(f"Configuration chargée: {len(software_list)} logiciels à installer")
        
        # Création des dossiers de base
        self.create_directories()
        
        # Installation des gestionnaires de paquets
        self.logger.info("Installation des gestionnaires de paquets...")
        winget_ok = self.install_winget()
        choco_ok = self.install_chocolatey()
        
        if not winget_ok and not choco_ok:
            self.logger.error("Impossible d'installer les gestionnaires de paquets!")
            return
        
        # Installation des logiciels
        self.logger.info("Début de l'installation des logiciels...")
        
        # Installation via winget
        if winget_ok:
            self.install_software_winget(software_list)
        
        # Installation via chocolatey
        if choco_ok:
            self.install_software_chocolatey(software_list)
        
        # Installation personnalisée
        self.logger.info("Installation des logiciels personnalisés...")
        for software in software_list:
            if software.get('method') == 'custom':
                name = software['name']
                if self.install_software_custom(software):
                    self.installed_software.append(name)
                    self.logger.info(f"✓ {name} installé avec succès")
                else:
                    self.failed_software.append(name)
                    self.logger.error(f"✗ Échec de l'installation de {name}")
        
        # Installation directe (legacy)
        self.install_software_direct(software_list)
        
        # Génération du rapport
        self.generate_report()
        
        self.logger.info("=== INSTALLATION TERMINÉE ===")
        self.logger.info(f"Logiciels installés: {len(self.installed_software)}")
        self.logger.info(f"Logiciels en échec: {len(self.failed_software)}")

def main():
    """Fonction principale"""
    installer = SoftwareInstaller()
    
    # Vérification de l'OS
    if sys.platform != "win32":
        print("Ce script est conçu pour Windows uniquement!")
        sys.exit(1)
    
    # Lancement de l'installation
    installer.run()

if __name__ == "__main__":
    main()
