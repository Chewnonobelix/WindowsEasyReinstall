#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Script de lancement simplifié pour l'installation des logiciels

.DESCRIPTION
    Ce script est un wrapper simplifié qui lance le script principal SoftwareInstaller.ps1
    avec des paramètres par défaut et une interface utilisateur simple.

.PARAMETER ConfigFile
    Fichier de configuration à utiliser (défaut: software_config_powershell.json)

.PARAMETER LogLevel
    Niveau de log (Verbose, Info, Warning, Error) (défaut: Info)

.PARAMETER SkipConfirmation
    Ignore la confirmation avant l'installation

.EXAMPLE
    .\Run-SoftwareInstaller.ps1

.EXAMPLE
    .\Run-SoftwareInstaller.ps1 -ConfigFile "ma_config.json" -LogLevel Verbose

.EXAMPLE
    .\Run-SoftwareInstaller.ps1 -SkipConfirmation
#>

param(
    [string]$ConfigFile = "software_config_powershell.json",
    [ValidateSet("Verbose", "Info", "Warning", "Error")]
    [string]$LogLevel = "Info",
    [switch]$SkipConfirmation
)

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
    Write-ColorMessage "║                INSTALLATEUR DE LOGICIELS                    ║" -Color "Cyan"
    Write-ColorMessage "║                    Version PowerShell                       ║" -Color "Cyan"
    Write-ColorMessage "╚══════════════════════════════════════════════════════════════╝" -Color "Cyan"
    Write-Host ""
}

# Fonction pour afficher le menu
function Show-Menu {
    Write-ColorMessage "Options disponibles :" -Color "Yellow"
    Write-Host ""
    Write-ColorMessage "1. Installer tous les logiciels" -Color "Green"
    Write-ColorMessage "2. Installer seulement les navigateurs" -Color "Green"
    Write-ColorMessage "3. Installer seulement les outils de développement" -Color "Green"
    Write-ColorMessage "4. Installer seulement les utilitaires" -Color "Green"
    Write-ColorMessage "5. Afficher la liste des logiciels" -Color "Green"
    Write-ColorMessage "6. Vérifier les prérequis" -Color "Green"
    Write-ColorMessage "7. Quitter" -Color "Red"
    Write-Host ""
}

# Fonction pour vérifier les prérequis
function Test-Prerequisites {
    Write-ColorMessage "Vérification des prérequis..." -Color "Yellow"
    Write-Host ""
    
    # Vérification des privilèges administrateur
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
    $IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($IsAdmin) {
        Write-ColorMessage "✓ Privilèges administrateur : OK" -Color "Green"
    } else {
        Write-ColorMessage "✗ Privilèges administrateur : REQUIS" -Color "Red"
        return $false
    }
    
    # Vérification de PowerShell
    $PSVersion = $PSVersionTable.PSVersion
    if ($PSVersion.Major -ge 5) {
        Write-ColorMessage "✓ PowerShell $($PSVersion.ToString()) : OK" -Color "Green"
    } else {
        Write-ColorMessage "✗ PowerShell $($PSVersion.ToString()) : Version 5.1+ requise" -Color "Red"
        return $false
    }
    
    # Vérification de la configuration
    if (Test-Path $ConfigFile) {
        Write-ColorMessage "✓ Fichier de configuration : OK" -Color "Green"
    } else {
        Write-ColorMessage "✗ Fichier de configuration : $ConfigFile non trouvé" -Color "Red"
        return $false
    }
    
    # Vérification de winget
    try {
        $WingetVersion = winget --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorMessage "✓ Winget : OK ($WingetVersion)" -Color "Green"
        } else {
            Write-ColorMessage "⚠ Winget : Non installé (sera installé automatiquement)" -Color "Yellow"
        }
    } catch {
        Write-ColorMessage "⚠ Winget : Non installé (sera installé automatiquement)" -Color "Yellow"
    }
    
    # Vérification de chocolatey
    try {
        $ChocoVersion = choco --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorMessage "✓ Chocolatey : OK ($ChocoVersion)" -Color "Green"
        } else {
            Write-ColorMessage "⚠ Chocolatey : Non installé (sera installé automatiquement)" -Color "Yellow"
        }
    } catch {
        Write-ColorMessage "⚠ Chocolatey : Non installé (sera installé automatiquement)" -Color "Yellow"
    }
    
    Write-Host ""
    return $true
}

# Fonction pour afficher la liste des logiciels
function Show-SoftwareList {
    Write-ColorMessage "Chargement de la liste des logiciels..." -Color "Yellow"
    
    try {
        $ConfigContent = Get-Content -Path $ConfigFile -Raw -Encoding UTF8
        $Config = $ConfigContent | ConvertFrom-Json -AsHashtable
        $SoftwareList = $Config.software_list
        
        Write-Host ""
        Write-ColorMessage "Logiciels configurés ($($SoftwareList.Count) au total) :" -Color "Cyan"
        Write-Host ""
        
        $Categories = $SoftwareList | Group-Object category
        foreach ($Category in $Categories) {
            Write-ColorMessage "📁 $($Category.Name) :" -Color "Yellow"
            foreach ($Software in $Category.Group) {
                $Method = switch ($Software.method) {
                    "winget" { "📦" }
                    "chocolatey" { "🍫" }
                    "custom" { "⚙️" }
                    default { "❓" }
                }
                Write-ColorMessage "  $Method $($Software.name)" -Color "White"
            }
            Write-Host ""
        }
    }
    catch {
        Write-ColorMessage "Erreur lors du chargement de la configuration : $($_.Exception.Message)" -Color "Red"
    }
}

# Fonction pour créer une configuration filtrée
function New-FilteredConfig {
    param(
        [string]$Filter
    )
    
    try {
        $ConfigContent = Get-Content -Path $ConfigFile -Raw -Encoding UTF8
        $Config = $ConfigContent | ConvertFrom-Json -AsHashtable
        $SoftwareList = $Config.software_list
        
        $FilteredSoftware = switch ($Filter) {
            "navigateurs" { $SoftwareList | Where-Object { $_.category -eq "Navigateur" } }
            "développement" { $SoftwareList | Where-Object { $_.category -eq "Développement" } }
            "utilitaires" { $SoftwareList | Where-Object { $_.category -eq "Utilitaires" } }
            default { $SoftwareList }
        }
        
        $FilteredConfig = @{
            base_directories = $Config.base_directories
            software_list = $FilteredSoftware
        }
        
        $TempConfigFile = "temp_config_$Filter.json"
        $FilteredConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $TempConfigFile -Encoding UTF8
        return $TempConfigFile
    }
    catch {
        Write-ColorMessage "Erreur lors de la création de la configuration filtrée : $($_.Exception.Message)" -Color "Red"
        return $ConfigFile
    }
}

# Fonction pour lancer l'installation
function Start-Installation {
    param(
        [string]$ConfigToUse = $ConfigFile,
        [string]$Description = "tous les logiciels"
    )
    
    Write-ColorMessage "Démarrage de l'installation de $Description..." -Color "Yellow"
    Write-Host ""
    
    if (-not $SkipConfirmation) {
        $Confirmation = Read-Host "Voulez-vous continuer ? (O/N)"
        if ($Confirmation -notmatch "^[OoYy]") {
            Write-ColorMessage "Installation annulée." -Color "Yellow"
            return
        }
    }
    
    try {
        & ".\SoftwareInstaller.ps1" -ConfigFile $ConfigToUse -LogLevel $LogLevel
    }
    catch {
        Write-ColorMessage "Erreur lors de l'exécution : $($_.Exception.Message)" -Color "Red"
    }
    finally {
        # Nettoyage des fichiers temporaires
        if ($ConfigToUse -ne $ConfigFile -and (Test-Path $ConfigToUse)) {
            Remove-Item $ConfigToUse -Force
        }
    }
}

# Fonction principale
function Start-Main {
    Show-Header
    
    # Vérification des prérequis
    if (-not (Test-Prerequisites)) {
        Write-ColorMessage "Prérequis non satisfaits. Arrêt du script." -Color "Red"
        Read-Host "Appuyez sur Entrée pour quitter"
        return
    }
    
    Write-Host ""
    Read-Host "Appuyez sur Entrée pour continuer"
    
    do {
        Show-Header
        Show-Menu
        
        $Choice = Read-Host "Votre choix (1-7)"
        
        switch ($Choice) {
            "1" {
                Start-Installation -Description "tous les logiciels"
            }
            "2" {
                $TempConfig = New-FilteredConfig -Filter "navigateurs"
                Start-Installation -ConfigToUse $TempConfig -Description "les navigateurs"
            }
            "3" {
                $TempConfig = New-FilteredConfig -Filter "développement"
                Start-Installation -ConfigToUse $TempConfig -Description "les outils de développement"
            }
            "4" {
                $TempConfig = New-FilteredConfig -Filter "utilitaires"
                Start-Installation -ConfigToUse $TempConfig -Description "les utilitaires"
            }
            "5" {
                Show-SoftwareList
                Read-Host "Appuyez sur Entrée pour continuer"
            }
            "6" {
                Test-Prerequisites
                Read-Host "Appuyez sur Entrée pour continuer"
            }
            "7" {
                Write-ColorMessage "Au revoir !" -Color "Green"
                return
            }
            default {
                Write-ColorMessage "Choix invalide. Veuillez sélectionner 1-7." -Color "Red"
                Start-Sleep -Seconds 2
            }
        }
        
        if ($Choice -in @("1", "2", "3", "4")) {
            Write-Host ""
            Read-Host "Appuyez sur Entrée pour revenir au menu principal"
        }
        
    } while ($Choice -ne "7")
}

# Point d'entrée
try {
    Start-Main
}
catch {
    Write-ColorMessage "Erreur fatale : $($_.Exception.Message)" -Color "Red"
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}
