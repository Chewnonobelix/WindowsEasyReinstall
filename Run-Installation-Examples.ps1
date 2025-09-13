#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Exemples d'utilisation du script Install-CustomSoftware.ps1

.DESCRIPTION
    Ce script montre différents exemples d'utilisation du script d'installation
    avec différents fichiers de configuration et paramètres.

.EXAMPLE
    .\Run-Installation-Examples.ps1
#>

# Configuration des couleurs
$Host.UI.RawUI.ForegroundColor = "White"

# Fonction pour afficher un message coloré
function Write-ColorMessage {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    $OriginalColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Message
    $Host.UI.RawUI.ForegroundColor = $OriginalColor
}

# Fonction pour afficher l'en-tête
function Show-Header {
    Clear-Host
    Write-ColorMessage "╔══════════════════════════════════════════════════════════════╗" -Color "Cyan"
    Write-ColorMessage "║              EXEMPLES D'UTILISATION                        ║" -Color "Cyan"
    Write-ColorMessage "║              Install-CustomSoftware.ps1                    ║" -Color "Cyan"
    Write-ColorMessage "╚══════════════════════════════════════════════════════════════╝" -Color "Cyan"
    Write-Host ""
}

# Fonction pour afficher le menu
function Show-Menu {
    Write-ColorMessage "Choisissez un exemple d'utilisation :" -Color "Yellow"
    Write-Host ""
    Write-ColorMessage "1. Afficher l'aide du script" -Color "Green"
    Write-ColorMessage "2. Installation avec configuration par défaut" -Color "Green"
    Write-ColorMessage "3. Installation avec configuration personnalisée" -Color "Green"
    Write-ColorMessage "4. Installation avec logs détaillés" -Color "Green"
    Write-ColorMessage "5. Installation automatique (sans confirmation)" -Color "Green"
    Write-ColorMessage "6. Installation avec configuration Python" -Color "Green"
    Write-ColorMessage "7. Installation avec configuration PowerShell" -Color "Green"
    Write-ColorMessage "8. Vérifier les fichiers de configuration disponibles" -Color "Green"
    Write-ColorMessage "9. Quitter" -Color "Red"
    Write-Host ""
}

# Fonction pour vérifier les fichiers de configuration
function Test-ConfigFiles {
    Write-ColorMessage "Vérification des fichiers de configuration disponibles..." -Color "Yellow"
    Write-Host ""
    
    $ConfigFiles = @(
        @{Name="software_config_custom.json"; Description="Configuration personnalisée complète"},
        @{Name="software_config_powershell.json"; Description="Configuration PowerShell standard"},
        @{Name="software_config.json"; Description="Configuration Python compatible"},
        @{Name="software_config_example.json"; Description="Exemple de configuration"}
    )
    
    foreach ($Config in $ConfigFiles) {
        if (Test-Path $Config.Name) {
            $FileSize = (Get-Item $Config.Name).Length
            $FileSizeKB = [math]::Round($FileSize / 1KB, 2)
            Write-ColorMessage "✓ $($Config.Name) ($FileSizeKB KB)" -Color "Green"
            Write-ColorMessage "  $($Config.Description)" -Color "Gray"
        } else {
            Write-ColorMessage "✗ $($Config.Name) (non trouvé)" -Color "Red"
        }
        Write-Host ""
    }
}

# Fonction pour exécuter une commande d'exemple
function Invoke-Example {
    param(
        [string]$Description,
        [string]$Command
    )
    
    Write-ColorMessage "Exemple: $Description" -Color "Cyan"
    Write-ColorMessage "Commande: $Command" -Color "White"
    Write-Host ""
    
    $Confirmation = Read-Host "Voulez-vous exécuter cette commande ? (O/N)"
    if ($Confirmation -match "^[OoYy]") {
        Write-ColorMessage "Exécution de la commande..." -Color "Yellow"
        Write-Host ""
        
        try {
            Invoke-Expression $Command
        }
        catch {
            Write-ColorMessage "Erreur lors de l'exécution: $($_.Exception.Message)" -Color "Red"
        }
    } else {
        Write-ColorMessage "Commande annulée." -Color "Yellow"
    }
    
    Write-Host ""
    Read-Host "Appuyez sur Entrée pour continuer"
}

# Fonction principale
function Start-Examples {
    Show-Header
    
    do {
        Show-Header
        Show-Menu
        
        $Choice = Read-Host "Votre choix (1-9)"
        
        switch ($Choice) {
            "1" {
                Invoke-Example "Afficher l'aide du script" ".\Install-CustomSoftware.ps1 -Help"
            }
            "2" {
                Invoke-Example "Installation avec configuration par défaut" ".\Install-CustomSoftware.ps1"
            }
            "3" {
                $CustomConfig = Read-Host "Nom du fichier de configuration personnalisé (ex: ma_config.json)"
                if ($CustomConfig) {
                    Invoke-Example "Installation avec configuration personnalisée" ".\Install-CustomSoftware.ps1 -ConfigFile '$CustomConfig'"
                } else {
                    Write-ColorMessage "Nom de fichier invalide." -Color "Red"
                    Read-Host "Appuyez sur Entrée pour continuer"
                }
            }
            "4" {
                Invoke-Example "Installation avec logs détaillés" ".\Install-CustomSoftware.ps1 -LogLevel Verbose"
            }
            "5" {
                Invoke-Example "Installation automatique (sans confirmation)" ".\Install-CustomSoftware.ps1 -SkipConfirmation"
            }
            "6" {
                Invoke-Example "Installation avec configuration Python" ".\Install-CustomSoftware.ps1 -ConfigFile 'software_config.json'"
            }
            "7" {
                Invoke-Example "Installation avec configuration PowerShell" ".\Install-CustomSoftware.ps1 -ConfigFile 'software_config_powershell.json'"
            }
            "8" {
                Test-ConfigFiles
                Read-Host "Appuyez sur Entrée pour continuer"
            }
            "9" {
                Write-ColorMessage "Au revoir !" -Color "Green"
                return
            }
            default {
                Write-ColorMessage "Choix invalide. Veuillez sélectionner 1-9." -Color "Red"
                Start-Sleep -Seconds 2
            }
        }
        
    } while ($Choice -ne "9")
}

# Point d'entrée
try {
    Start-Examples
}
catch {
    Write-ColorMessage "Erreur fatale : $($_.Exception.Message)" -Color "Red"
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}
