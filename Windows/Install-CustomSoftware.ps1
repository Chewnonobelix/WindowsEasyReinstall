#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Script d'installation des logiciels personnalisés

.DESCRIPTION
    Ce script installe une liste personnalisée de logiciels en utilisant winget,
    chocolatey et des installateurs personnalisés selon la configuration JSON.

.PARAMETER ConfigFile
    Fichier de configuration JSON (défaut: software_config_custom.json)

.PARAMETER LogLevel
    Niveau de log (Verbose, Info, Warning, Error) (défaut: Info)

.PARAMETER SkipConfirmation
    Ignore la confirmation avant l'installation

.EXAMPLE
    .\Install-CustomSoftware.ps1

.EXAMPLE
    .\Install-CustomSoftware.ps1 -ConfigFile "ma_config.json" -LogLevel Verbose
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "software_config_custom.json",
    [ValidateSet("Verbose", "Info", "Warning", "Error")]
    [string]$LogLevel = "Info",
    [switch]$SkipConfirmation,
    [switch]$Help
)

# Configuration des couleurs
$Host.UI.RawUI.ForegroundColor = "White"

# Variables globales
$Global:InstalledSoftware = @()
$Global:FailedSoftware = @()
$Global:BaseDirectories = @{}
$Global:Config = @{}

# Fonction pour afficher l'aide
function Show-Help {
    Write-ColorMessage "╔══════════════════════════════════════════════════════════════╗" -Color "Cyan"
    Write-ColorMessage "║              INSTALLATION DE LOGICIELS PERSONNALISÉS       ║" -Color "Cyan"
    Write-ColorMessage "║                    Version PowerShell                       ║" -Color "Cyan"
    Write-ColorMessage "╚══════════════════════════════════════════════════════════════╝" -Color "Cyan"
    Write-Host ""
    Write-ColorMessage "UTILISATION:" -Color "Yellow"
    Write-Host ""
    Write-ColorMessage "  .\Install-CustomSoftware.ps1 [PARAMÈTRES]" -Color "White"
    Write-Host ""
    Write-ColorMessage "PARAMÈTRES:" -Color "Yellow"
    Write-Host ""
    Write-ColorMessage "  -ConfigFile <fichier>    Fichier de configuration JSON" -Color "Green"
    Write-ColorMessage "                          (défaut: software_config_custom.json)" -Color "Gray"
    Write-Host ""
    Write-ColorMessage "  -LogLevel <niveau>       Niveau de log (Verbose, Info, Warning, Error)" -Color "Green"
    Write-ColorMessage "                          (défaut: Info)" -Color "Gray"
    Write-Host ""
    Write-ColorMessage "  -SkipConfirmation        Ignore la confirmation avant l'installation" -Color "Green"
    Write-Host ""
    Write-ColorMessage "  -Help                    Affiche cette aide" -Color "Green"
    Write-Host ""
    Write-ColorMessage "EXEMPLES:" -Color "Yellow"
    Write-Host ""
    Write-ColorMessage "  .\Install-CustomSoftware.ps1" -Color "White"
    Write-ColorMessage "  .\Install-CustomSoftware.ps1 -ConfigFile 'ma_config.json'" -Color "White"
    Write-ColorMessage "  .\Install-CustomSoftware.ps1 -LogLevel Verbose -SkipConfirmation" -Color "White"
    Write-ColorMessage "  .\Install-CustomSoftware.ps1 -ConfigFile 'config_dev.json' -LogLevel Verbose" -Color "White"
    Write-Host ""
    Write-ColorMessage "FICHIERS DE CONFIGURATION DISPONIBLES:" -Color "Yellow"
    Write-Host ""
    Write-ColorMessage "  software_config_custom.json     - Configuration personnalisée complète" -Color "White"
    Write-ColorMessage "  software_config_powershell.json - Configuration PowerShell standard" -Color "White"
    Write-ColorMessage "  software_config.json           - Configuration Python compatible" -Color "White"
    Write-Host ""
}

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

# Fonction de logging
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Verbose", "Info", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Écriture dans le fichier de log
    Add-Content -Path "custom_software_installer.log" -Value $LogEntry -Encoding UTF8
    
    # Affichage dans la console selon le niveau
    switch ($Level) {
        "Verbose" { if ($LogLevel -eq "Verbose") { Write-ColorMessage $LogEntry -Color Gray } }
        "Info" { if ($LogLevel -in @("Verbose", "Info")) { Write-ColorMessage $LogEntry -Color White } }
        "Warning" { if ($LogLevel -in @("Verbose", "Info", "Warning")) { Write-ColorMessage $LogEntry -Color Yellow } }
        "Error" { Write-ColorMessage $LogEntry -Color Red }
    }
}

# Fonction pour exécuter une commande
function Invoke-CommandWithLog {
    param(
        [string]$Command,
        [string[]]$Arguments = @(),
        [int]$TimeoutSeconds = 300,
        [string]$Description = ""
    )
    
    try {
        Write-Log "Exécution: $Command $($Arguments -join ' ')" -Level Info
        if ($Description) { Write-Log $Description -Level Info }
        
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = $Command
        $ProcessInfo.Arguments = $Arguments -join ' '
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError = $true
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.CreateNoWindow = $true
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo
        $Process.Start() | Out-Null
        
        $Output = $Process.StandardOutput.ReadToEnd()
        $Error = $Process.StandardError.ReadToEnd()
        
        $Process.WaitForExit($TimeoutSeconds * 1000)
        
        if ($Process.ExitCode -eq 0) {
            Write-Log "Commande réussie: $Command" -Level Info
            return @{ Success = $true; Output = $Output; Error = $Error }
        } else {
            Write-Log "Erreur dans la commande: $Command (Code: $($Process.ExitCode))" -Level Error
            Write-Log "Erreur: $Error" -Level Error
            return @{ Success = $false; Output = $Output; Error = $Error }
        }
    }
    catch {
        Write-Log "Exception lors de l'exécution: $($_.Exception.Message)" -Level Error
        return @{ Success = $false; Output = ""; Error = $_.Exception.Message }
    }
}

# Fonction pour vérifier les privilèges administrateur
function Test-Administrator {
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Fonction pour étendre les variables d'environnement dans un chemin
function Expand-PathVariables {
    param([string]$Path)
    return [System.Environment]::ExpandEnvironmentVariables($Path)
}

# Fonction pour créer les dossiers de base
function New-BaseDirectories {
    Write-Log "Création des dossiers de base..." -Level Info
    
    # Créer d'abord le dossier principal D:\Utils
    $UtilsDir = "D:\Utils"
    try {
        if (-not (Test-Path $UtilsDir)) {
            New-Item -ItemType Directory -Path $UtilsDir -Force | Out-Null
            Write-Log "✓ Dossier principal créé: $UtilsDir" -Level Info
        } else {
            Write-Log "✓ Dossier principal existant: $UtilsDir" -Level Info
        }
    }
    catch {
        Write-Log "✗ Erreur création dossier principal D:\Utils : $($_.Exception.Message)" -Level Error
        Write-Log "Vérifiez les permissions et l'espace disque sur le lecteur D:" -Level Warning
    }
    
    # Créer les autres dossiers de base
    foreach ($DirName in $Global:BaseDirectories.Keys) {
        $DirPath = Expand-PathVariables $Global:BaseDirectories[$DirName]
        try {
            if (-not (Test-Path $DirPath)) {
                New-Item -ItemType Directory -Path $DirPath -Force | Out-Null
                Write-Log "✓ Dossier créé: $DirPath" -Level Info
            } else {
                Write-Log "✓ Dossier existant: $DirPath" -Level Info
            }
        }
        catch {
            Write-Log "✗ Erreur création dossier $DirName : $($_.Exception.Message)" -Level Error
        }
    }
}

# Fonction pour installer winget
function Install-Winget {
    Write-Log "Vérification de winget..." -Level Info
    
    $WingetCheck = Invoke-CommandWithLog "winget" @("--version")
    if ($WingetCheck.Success) {
        Write-Log "Winget est déjà installé" -Level Info
        return $true
    }
    
    Write-Log "Installation de winget..." -Level Info
    $WingetInstall = Invoke-CommandWithLog "powershell" @(
        "-Command",
        "Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
    )
    
    if ($WingetInstall.Success) {
        Write-Log "Winget installé avec succès" -Level Info
        return $true
    } else {
        Write-Log "Échec de l'installation de winget" -Level Error
        return $false
    }
}

# Fonction pour installer chocolatey
function Install-Chocolatey {
    Write-Log "Vérification de chocolatey..." -Level Info
    
    $ChocoCheck = Invoke-CommandWithLog "choco" @("--version")
    if ($ChocoCheck.Success) {
        Write-Log "Chocolatey est déjà installé" -Level Info
        return $true
    }
    
    Write-Log "Installation de chocolatey..." -Level Info
    $ChocoInstall = Invoke-CommandWithLog "powershell" @(
        "-Command",
        "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    )
    
    if ($ChocoInstall.Success) {
        Write-Log "Chocolatey installé avec succès" -Level Info
        return $true
    } else {
        Write-Log "Échec de l'installation de chocolatey" -Level Error
        return $false
    }
}

# Fonction pour télécharger un fichier
function Get-FileDownload {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Description = ""
    )
    
    try {
        Write-Log "Téléchargement de $Url vers $Destination" -Level Info
        if ($Description) { Write-Log $Description -Level Info }
        
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($Url, $Destination)
        
        Write-Log "✓ Téléchargement réussi: $(Split-Path $Destination -Leaf)" -Level Info
        return $true
    }
    catch {
        Write-Log "✗ Erreur téléchargement $(Split-Path $Destination -Leaf): $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Fonction pour extraire un fichier ZIP
function Expand-ZipFile {
    param(
        [string]$ZipFile,
        [string]$Destination,
        [string]$Description = ""
    )
    
    try {
        Write-Log "Extraction de $ZipFile vers $Destination" -Level Info
        if ($Description) { Write-Log $Description -Level Info }
        
        # Créer le dossier de destination s'il n'existe pas
        if (-not (Test-Path $Destination)) {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        }
        
        # Extraire le ZIP
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $Destination)
        
        Write-Log "✓ Extraction réussie: $(Split-Path $ZipFile -Leaf)" -Level Info
        return $true
    }
    catch {
        Write-Log "✗ Erreur extraction $(Split-Path $ZipFile -Leaf): $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Fonction pour exécuter des commandes
function Invoke-CommandList {
    param(
        [string[]]$Commands,
        [string]$SoftwareName
    )
    
    foreach ($Command in $Commands) {
        Write-Log "Exécution commande pour $SoftwareName : $Command" -Level Info
        $Result = Invoke-CommandWithLog "cmd" @("/c", $Command)
        if (-not $Result.Success) {
            Write-Log "✗ Commande échouée: $Command" -Level Error
            return $false
        }
    }
    return $true
}

# Fonction pour installer un logiciel via winget
function Install-SoftwareWinget {
    param([hashtable]$Software)
    
    $Name = $Software.name
    $PackageId = $Software.package_id
    $InstallerConfig = $Software.installer
    $BaseDirectory = $Software.base_directory
    
    # Arguments silencieux par défaut ou depuis la configuration
    $SilentArgs = if ($InstallerConfig.silent_args) { $InstallerConfig.silent_args } else { @("--accept-package-agreements", "--accept-source-agreements", "--silent") }
    
    Write-Log "Installation de $Name..." -Level Info
    $Result = Invoke-CommandWithLog "winget" @("install", $PackageId) + $SilentArgs
    
    if ($Result.Success) {
        $Global:InstalledSoftware += $Name
        Write-Log "✓ $Name installé avec succès" -Level Info
        
        # Vérification et création du dossier de base
        if ($BaseDirectory) {
            $ExpandedBaseDir = Expand-PathVariables $BaseDirectory
            try {
                if (-not (Test-Path $ExpandedBaseDir)) {
                    New-Item -ItemType Directory -Path $ExpandedBaseDir -Force | Out-Null
                    Write-Log "✓ Dossier de base créé: $ExpandedBaseDir" -Level Info
                } else {
                    Write-Log "✓ Dossier de base vérifié: $ExpandedBaseDir" -Level Info
                }
            }
            catch {
                Write-Log "⚠ Impossible de créer/vérifier le dossier: $ExpandedBaseDir" -Level Warning
            }
        }
        return $true
    } else {
        $Global:FailedSoftware += $Name
        Write-Log "✗ Échec de l'installation de $Name" -Level Error
        return $false
    }
}

# Fonction pour installer un logiciel personnalisé
function Install-SoftwareCustom {
    param([hashtable]$Software)
    
    $Name = $Software.name
    $InstallerConfig = $Software.installer
    $BaseDirectory = $Software.base_directory
    
    if ($InstallerConfig.type -ne "custom") {
        return $false
    }
    
    Write-Log "Installation personnalisée de $Name..." -Level Info
    
    # Récupération des chemins
    $InstallersDir = Expand-PathVariables $Global:BaseDirectories.installers
    $TempDir = Expand-PathVariables $Global:BaseDirectories.temp
    
    # Commandes pré-installation
    $PreCommands = $InstallerConfig.pre_install_commands
    if ($PreCommands) {
        Write-Log "Exécution des commandes pré-installation pour $Name" -Level Info
        if (-not (Invoke-CommandList -Commands $PreCommands -SoftwareName $Name)) {
            return $false
        }
    }
    
    # Téléchargement si nécessaire
    $DownloadUrl = $InstallerConfig.download_url
    if ($DownloadUrl) {
        $Filename = if ($InstallerConfig.filename) { $InstallerConfig.filename } else { (Split-Path $DownloadUrl -Leaf) }
        $InstallerPath = Join-Path $InstallersDir $Filename
        
        if (-not (Get-FileDownload -Url $DownloadUrl -Destination $InstallerPath)) {
            return $false
        }
        
        # Gestion des fichiers ZIP (comme Nucleus Coop)
        if ($Filename.EndsWith(".zip")) {
            $ExtractDir = $BaseDirectory
            if (-not (Expand-ZipFile -ZipFile $InstallerPath -Destination $ExtractDir)) {
                return $false
            }
        } else {
            # Installation normale pour les exécutables
            $SilentArgs = $InstallerConfig.silent_args
            $InstallCommand = "`"$InstallerPath`" $($SilentArgs -join ' ')"
            
            Write-Log "Installation de $Name..." -Level Info
            $Result = Invoke-CommandWithLog "cmd" @("/c", $InstallCommand)
            
            if (-not $Result.Success) {
                Write-Log "✗ Échec installation $Name" -Level Error
                return $false
            }
        }
    }
    
    # Commandes post-installation
    $PostCommands = $InstallerConfig.post_install_commands
    if ($PostCommands) {
        Write-Log "Exécution des commandes post-installation pour $Name" -Level Info
        if (-not (Invoke-CommandList -Commands $PostCommands -SoftwareName $Name)) {
            return $false
        }
    }
    
    # Vérification et création du dossier de base
    if ($BaseDirectory) {
        $ExpandedBaseDir = Expand-PathVariables $BaseDirectory
        try {
            if (-not (Test-Path $ExpandedBaseDir)) {
                New-Item -ItemType Directory -Path $ExpandedBaseDir -Force | Out-Null
                Write-Log "✓ Dossier de base créé: $ExpandedBaseDir" -Level Info
            } else {
                Write-Log "✓ Dossier de base vérifié: $ExpandedBaseDir" -Level Info
            }
        }
        catch {
            Write-Log "⚠ Impossible de créer/vérifier le dossier: $ExpandedBaseDir" -Level Warning
        }
    }
    
    return $true
}

# Fonction pour charger la configuration
function Get-SoftwareConfig {
    param([string]$ConfigFile)
    
    # Vérifier si le fichier existe
    if (-not (Test-Path $ConfigFile)) {
        Write-ColorMessage "✗ Fichier de configuration '$ConfigFile' non trouvé !" -Color "Red"
        Write-ColorMessage "Vérifiez le chemin et réessayez." -Color "Yellow"
        Write-ColorMessage "Utilisez -Help pour voir les options disponibles." -Color "Yellow"
        return $null
    }
    
    # Vérifier l'extension du fichier
    if (-not $ConfigFile.EndsWith(".json")) {
        Write-ColorMessage "⚠ Le fichier '$ConfigFile' n'a pas l'extension .json" -Color "Yellow"
        Write-ColorMessage "Assurez-vous que c'est un fichier de configuration valide." -Color "Yellow"
    }
    
    try {
        Write-ColorMessage "Chargement de la configuration depuis: $ConfigFile" -Color "Cyan"
        $ConfigContent = Get-Content -Path $ConfigFile -Raw -Encoding UTF8
        $Config = $ConfigContent | ConvertFrom-Json -AsHashtable
        $Global:Config = $Config
        $Global:BaseDirectories = $Config.base_directories
        Write-ColorMessage "✓ Configuration chargée avec succès" -Color "Green"
        return $Config
    }
    catch {
        Write-ColorMessage "✗ Erreur lors du chargement de la configuration: $($_.Exception.Message)" -Color "Red"
        Write-ColorMessage "Vérifiez que le fichier JSON est valide." -Color "Yellow"
        return $null
    }
}

# Fonction pour générer le rapport
function New-InstallationReport {
    $ReportContent = @"
=== RAPPORT D'INSTALLATION PERSONNALISÉE ===

Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

LOGICIELS INSTALLÉS AVEC SUCCÈS:
$('-' * 40)
$($Global:InstalledSoftware | ForEach-Object { "✓ $_" }) -join "`n"

LOGICIELS EN ÉCHEC:
$('-' * 40)
$($Global:FailedSoftware | ForEach-Object { "✗ $_" }) -join "`n"

RÉSUMÉ:
$('-' * 40)
Total installé: $($Global:InstalledSoftware.Count)
Total en échec: $($Global:FailedSoftware.Count)

NOTES:
- Certains logiciels nécessitent une installation manuelle
- Vérifiez les logs pour plus de détails
- Les logiciels en échec peuvent nécessiter une intervention manuelle
"@
    
    $ReportContent | Out-File -FilePath "custom_installation_report.txt" -Encoding UTF8
    Write-Log "Rapport généré: custom_installation_report.txt" -Level Info
}

# Fonction pour afficher l'en-tête
function Show-Header {
    Clear-Host
    Write-ColorMessage "╔══════════════════════════════════════════════════════════════╗" -Color "Cyan"
    Write-ColorMessage "║              INSTALLATION DE LOGICIELS PERSONNALISÉS       ║" -Color "Cyan"
    Write-ColorMessage "║                    Version PowerShell                       ║" -Color "Cyan"
    Write-ColorMessage "╚══════════════════════════════════════════════════════════════╝" -Color "Cyan"
    Write-Host ""
}

# Fonction pour afficher le résumé des logiciels
function Show-SoftwareSummary {
    param([array]$SoftwareList)
    
    Write-ColorMessage "Logiciels à installer ($($SoftwareList.Count) au total) :" -Color "Yellow"
    Write-Host ""
    
    $Categories = $SoftwareList | Group-Object category
    foreach ($Category in $Categories) {
        Write-ColorMessage "📁 $($Category.Name) :" -Color "Cyan"
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

# Fonction principale
function Start-CustomSoftwareInstallation {
    param([string]$ConfigFile)
    
    # Afficher l'aide si demandé
    if ($Help) {
        Show-Help
        return
    }
    
    Show-Header
    
    # Afficher les informations de configuration
    Write-ColorMessage "Configuration utilisée: $ConfigFile" -Color "Cyan"
    Write-ColorMessage "Niveau de log: $LogLevel" -Color "Cyan"
    if ($SkipConfirmation) {
        Write-ColorMessage "Mode: Installation automatique (sans confirmation)" -Color "Cyan"
    } else {
        Write-ColorMessage "Mode: Installation interactive" -Color "Cyan"
    }
    Write-Host ""
    
    # Vérification des privilèges administrateur
    if (-not (Test-Administrator)) {
        Write-ColorMessage "Ce script doit être exécuté en tant qu'administrateur!" -Color "Red"
        Write-ColorMessage "Fermeture du script..." -Color "Yellow"
        return
    }
    
    # Chargement de la configuration
    $Config = Get-SoftwareConfig -ConfigFile $ConfigFile
    if (-not $Config) {
        Write-ColorMessage "Impossible de charger la configuration. Arrêt du script." -Color "Red"
        Write-ColorMessage "Utilisez -Help pour voir les options disponibles." -Color "Yellow"
        return
    }
    
    $SoftwareList = $Config.software_list
    Write-Log "Configuration chargée: $($SoftwareList.Count) logiciels à installer" -Level Info
    
    # Affichage du résumé
    Show-SoftwareSummary -SoftwareList $SoftwareList
    
    if (-not $SkipConfirmation) {
        $Confirmation = Read-Host "Voulez-vous continuer avec l'installation ? (O/N)"
        if ($Confirmation -notmatch "^[OoYy]") {
            Write-ColorMessage "Installation annulée." -Color "Yellow"
            return
        }
    }
    
    # Création des dossiers de base
    New-BaseDirectories
    
    # Installation des gestionnaires de paquets
    Write-Log "Installation des gestionnaires de paquets..." -Level Info
    $WingetOk = Install-Winget
    $ChocoOk = Install-Chocolatey
    
    if (-not $WingetOk -and -not $ChocoOk) {
        Write-Log "Impossible d'installer les gestionnaires de paquets!" -Level Error
        return
    }
    
    # Installation des logiciels
    Write-Log "Début de l'installation des logiciels..." -Level Info
    
    # Installation via winget
    if ($WingetOk) {
        Write-Log "Installation des logiciels via winget..." -Level Info
        foreach ($Software in $SoftwareList) {
            if ($Software.method -eq "winget") {
                Install-SoftwareWinget -Software $Software
            }
        }
    }
    
    # Installation personnalisée
    Write-Log "Installation des logiciels personnalisés..." -Level Info
    foreach ($Software in $SoftwareList) {
        if ($Software.method -eq "custom") {
            $Name = $Software.name
            if (Install-SoftwareCustom -Software $Software) {
                $Global:InstalledSoftware += $Name
                Write-Log "✓ $Name installé avec succès" -Level Info
            } else {
                $Global:FailedSoftware += $Name
                Write-Log "✗ Échec de l'installation de $Name" -Level Error
            }
        }
    }
    
    # Génération du rapport
    New-InstallationReport
    
    Write-Log "=== INSTALLATION TERMINÉE ===" -Level Info
    Write-Log "Logiciels installés: $($Global:InstalledSoftware.Count)" -Level Info
    Write-Log "Logiciels en échec: $($Global:FailedSoftware.Count)" -Level Info
    
    # Affichage du résumé final
    Write-Host ""
    Write-ColorMessage "=== RÉSUMÉ FINAL ===" -Color "Cyan"
    Write-ColorMessage "✓ Logiciels installés: $($Global:InstalledSoftware.Count)" -Color "Green"
    Write-ColorMessage "✗ Logiciels en échec: $($Global:FailedSoftware.Count)" -Color "Red"
    
    if ($Global:FailedSoftware.Count -gt 0) {
        Write-Host ""
        Write-ColorMessage "Logiciels nécessitant une installation manuelle :" -Color "Yellow"
        foreach ($Failed in $Global:FailedSoftware) {
            Write-ColorMessage "  - $Failed" -Color "Yellow"
        }
    }
}

# Point d'entrée du script
try {
    Start-CustomSoftwareInstallation -ConfigFile $ConfigFile
}
catch {
    Write-Log "Erreur fatale: $($_.Exception.Message)" -Level Error
    exit 1
}
