#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Script d'installation des prérequis pour SoftwareInstaller

.DESCRIPTION
    Ce script installe automatiquement les prérequis nécessaires pour l'exécution
    du script SoftwareInstaller.ps1, notamment winget et chocolatey.

.PARAMETER Force
    Force l'installation même si les outils sont déjà présents

.EXAMPLE
    .\Install-Requirements.ps1

.EXAMPLE
    .\Install-Requirements.ps1 -Force
#>

param(
    [switch]$Force
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
    Write-ColorMessage "║              INSTALLATION DES PRÉREQUIS                     ║" -Color "Cyan"
    Write-ColorMessage "║                    Version PowerShell                       ║" -Color "Cyan"
    Write-ColorMessage "╚══════════════════════════════════════════════════════════════╝" -Color "Cyan"
    Write-Host ""
}

# Fonction pour vérifier si un outil est installé
function Test-ToolInstalled {
    param(
        [string]$ToolName,
        [string]$Command,
        [string[]]$Arguments = @()
    )
    
    try {
        $Result = & $Command $Arguments 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Fonction pour installer winget
function Install-WingetTool {
    Write-ColorMessage "Installation de winget..." -Color "Yellow"
    
    try {
        # Méthode 1 : Via Microsoft Store
        Write-ColorMessage "Tentative d'installation via Microsoft Store..." -Color "Info"
        $StoreInstall = Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorMessage "✓ Winget installé via Microsoft Store" -Color "Green"
            return $true
        }
        
        # Méthode 2 : Téléchargement direct
        Write-ColorMessage "Tentative d'installation via téléchargement direct..." -Color "Info"
        $WingetUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $WingetFile = "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"
        
        Invoke-WebRequest -Uri $WingetUrl -OutFile $WingetFile -UseBasicParsing
        Add-AppxPackage -Path $WingetFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorMessage "✓ Winget installé via téléchargement" -Color "Green"
            Remove-Item $WingetFile -Force -ErrorAction SilentlyContinue
            return $true
        }
        
        Write-ColorMessage "✗ Échec de l'installation de winget" -Color "Red"
        return $false
    }
    catch {
        Write-ColorMessage "✗ Erreur lors de l'installation de winget : $($_.Exception.Message)" -Color "Red"
        return $false
    }
}

# Fonction pour installer chocolatey
function Install-ChocolateyTool {
    Write-ColorMessage "Installation de chocolatey..." -Color "Yellow"
    
    try {
        # Configuration de la politique d'exécution
        Set-ExecutionPolicy Bypass -Scope Process -Force
        
        # Configuration du protocole de sécurité
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        
        # Installation de chocolatey
        $ChocoInstallScript = "https://community.chocolatey.org/install.ps1"
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($ChocoInstallScript))
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorMessage "✓ Chocolatey installé avec succès" -Color "Green"
            return $true
        } else {
            Write-ColorMessage "✗ Échec de l'installation de chocolatey" -Color "Red"
            return $false
        }
    }
    catch {
        Write-ColorMessage "✗ Erreur lors de l'installation de chocolatey : $($_.Exception.Message)" -Color "Red"
        return $false
    }
}

# Fonction pour installer PowerShell 7 (optionnel)
function Install-PowerShell7 {
    Write-ColorMessage "Installation de PowerShell 7 (optionnel)..." -Color "Yellow"
    
    try {
        # Vérification si PowerShell 7 est déjà installé
        if (Test-Path "C:\Program Files\PowerShell\7\pwsh.exe") {
            Write-ColorMessage "✓ PowerShell 7 déjà installé" -Color "Green"
            return $true
        }
        
        # Installation via winget si disponible
        if (Test-ToolInstalled -ToolName "winget" -Command "winget") {
            Write-ColorMessage "Installation via winget..." -Color "Info"
            winget install Microsoft.PowerShell --accept-package-agreements --accept-source-agreements --silent
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorMessage "✓ PowerShell 7 installé via winget" -Color "Green"
                return $true
            }
        }
        
        # Installation via chocolatey si disponible
        if (Test-ToolInstalled -ToolName "choco" -Command "choco") {
            Write-ColorMessage "Installation via chocolatey..." -Color "Info"
            choco install powershell-core -y
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorMessage "✓ PowerShell 7 installé via chocolatey" -Color "Green"
                return $true
            }
        }
        
        Write-ColorMessage "⚠ PowerShell 7 non installé (optionnel)" -Color "Yellow"
        return $false
    }
    catch {
        Write-ColorMessage "⚠ Erreur lors de l'installation de PowerShell 7 : $($_.Exception.Message)" -Color "Yellow"
        return $false
    }
}

# Fonction pour vérifier les prérequis système
function Test-SystemRequirements {
    Write-ColorMessage "Vérification des prérequis système..." -Color "Yellow"
    Write-Host ""
    
    # Vérification de Windows
    $OSVersion = [System.Environment]::OSVersion.Version
    if ($OSVersion.Major -ge 10) {
        Write-ColorMessage "✓ Windows $($OSVersion.Major).$($OSVersion.Minor) : OK" -Color "Green"
    } else {
        Write-ColorMessage "✗ Windows $($OSVersion.Major).$($OSVersion.Minor) : Windows 10+ requis" -Color "Red"
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
    
    # Vérification de la connexion Internet
    try {
        $TestConnection = Test-NetConnection -ComputerName "www.microsoft.com" -Port 443 -InformationLevel Quiet
        if ($TestConnection) {
            Write-ColorMessage "✓ Connexion Internet : OK" -Color "Green"
        } else {
            Write-ColorMessage "⚠ Connexion Internet : Problème détecté" -Color "Yellow"
        }
    }
    catch {
        Write-ColorMessage "⚠ Connexion Internet : Impossible à vérifier" -Color "Yellow"
    }
    
    Write-Host ""
    return $true
}

# Fonction principale
function Start-RequirementsInstallation {
    Show-Header
    
    # Vérification des prérequis système
    if (-not (Test-SystemRequirements)) {
        Write-ColorMessage "Prérequis système non satisfaits. Arrêt du script." -Color "Red"
        Read-Host "Appuyez sur Entrée pour quitter"
        return
    }
    
    Write-ColorMessage "Démarrage de l'installation des prérequis..." -Color "Yellow"
    Write-Host ""
    
    $InstallationResults = @{
        Winget = $false
        Chocolatey = $false
        PowerShell7 = $false
    }
    
    # Installation de winget
    if ($Force -or -not (Test-ToolInstalled -ToolName "winget" -Command "winget" -Arguments @("--version"))) {
        $InstallationResults.Winget = Install-WingetTool
    } else {
        Write-ColorMessage "✓ Winget déjà installé" -Color "Green"
        $InstallationResults.Winget = $true
    }
    
    Write-Host ""
    
    # Installation de chocolatey
    if ($Force -or -not (Test-ToolInstalled -ToolName "choco" -Command "choco" -Arguments @("--version"))) {
        $InstallationResults.Chocolatey = Install-ChocolateyTool
    } else {
        Write-ColorMessage "✓ Chocolatey déjà installé" -Color "Green"
        $InstallationResults.Chocolatey = $true
    }
    
    Write-Host ""
    
    # Installation de PowerShell 7 (optionnel)
    $InstallationResults.PowerShell7 = Install-PowerShell7
    
    Write-Host ""
    
    # Résumé de l'installation
    Write-ColorMessage "=== RÉSUMÉ DE L'INSTALLATION ===" -Color "Cyan"
    Write-Host ""
    
    if ($InstallationResults.Winget) {
        Write-ColorMessage "✓ Winget : Installé" -Color "Green"
    } else {
        Write-ColorMessage "✗ Winget : Échec" -Color "Red"
    }
    
    if ($InstallationResults.Chocolatey) {
        Write-ColorMessage "✓ Chocolatey : Installé" -Color "Green"
    } else {
        Write-ColorMessage "✗ Chocolatey : Échec" -Color "Red"
    }
    
    if ($InstallationResults.PowerShell7) {
        Write-ColorMessage "✓ PowerShell 7 : Installé" -Color "Green"
    } else {
        Write-ColorMessage "⚠ PowerShell 7 : Non installé (optionnel)" -Color "Yellow"
    }
    
    Write-Host ""
    
    if ($InstallationResults.Winget -or $InstallationResults.Chocolatey) {
        Write-ColorMessage "✓ Prérequis installés avec succès !" -Color "Green"
        Write-ColorMessage "Vous pouvez maintenant exécuter SoftwareInstaller.ps1" -Color "Info"
    } else {
        Write-ColorMessage "✗ Échec de l'installation des prérequis" -Color "Red"
        Write-ColorMessage "Vérifiez votre connexion Internet et réessayez" -Color "Yellow"
    }
    
    Write-Host ""
    Read-Host "Appuyez sur Entrée pour quitter"
}

# Point d'entrée
try {
    Start-RequirementsInstallation
}
catch {
    Write-ColorMessage "Erreur fatale : $($_.Exception.Message)" -Color "Red"
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}
