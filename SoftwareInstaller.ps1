#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Script de réinstallation automatique des logiciels pour Windows 11
    Utilise winget et chocolatey pour installer les logiciels courants

.DESCRIPTION
    Ce script automatise la réinstallation des logiciels sur un PC Windows 11 fraîchement réinstallé.
    Il supporte l'installation via winget, chocolatey et des installateurs personnalisés.

.PARAMETER ConfigFile
    Chemin vers le fichier de configuration JSON (défaut: software_config.json)

.PARAMETER LogLevel
    Niveau de log (Verbose, Info, Warning, Error) (défaut: Info)

.EXAMPLE
    .\SoftwareInstaller.ps1

.EXAMPLE
    .\SoftwareInstaller.ps1 -ConfigFile "ma_config.json" -LogLevel Verbose

.NOTES
    Auteur: Assistant IA
    Version: 1.0
    Nécessite: Windows 10/11, PowerShell 5.1+, Privilèges administrateur
#>

param(
    [string]$ConfigFile = "software_config.json",
    [ValidateSet("Verbose", "Info", "Warning", "Error")]
    [string]$LogLevel = "Info"
)

# Configuration du logging
$LogFile = "software_installer.log"
$ReportFile = "installation_report.txt"

# Variables globales
$Global:InstalledSoftware = @()
$Global:FailedSoftware = @()
$Global:BaseDirectories = @{}
$Global:Config = @{}

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
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
    
    # Affichage dans la console selon le niveau
    switch ($Level) {
        "Verbose" { if ($LogLevel -eq "Verbose") { Write-Host $LogEntry -ForegroundColor Gray } }
        "Info" { if ($LogLevel -in @("Verbose", "Info")) { Write-Host $LogEntry -ForegroundColor White } }
        "Warning" { if ($LogLevel -in @("Verbose", "Info", "Warning")) { Write-Host $LogEntry -ForegroundColor Yellow } }
        "Error" { Write-Host $LogEntry -ForegroundColor Red }
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

# Fonction pour vérifier le checksum
function Test-FileChecksum {
    param(
        [string]$FilePath,
        [string]$ExpectedChecksum
    )
    
    try {
        if (-not $ExpectedChecksum.StartsWith("sha256:")) {
            Write-Log "Type de checksum non supporté: $ExpectedChecksum" -Level Warning
            return $true
        }
        
        $ExpectedHash = $ExpectedChecksum.Substring(7)  # Enlever 'sha256:'
        $FileHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
        
        if ($FileHash -eq $ExpectedHash.ToLower()) {
            Write-Log "✓ Checksum vérifié: $(Split-Path $FilePath -Leaf)" -Level Info
            return $true
        } else {
            Write-Log "✗ Checksum invalide: $(Split-Path $FilePath -Leaf)" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "✗ Erreur vérification checksum: $($_.Exception.Message)" -Level Error
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
        
        # Vérification du dossier de base
        if ($BaseDirectory) {
            $ExpandedBaseDir = Expand-PathVariables $BaseDirectory
            if (Test-Path $ExpandedBaseDir) {
                Write-Log "✓ Dossier de base vérifié: $ExpandedBaseDir" -Level Info
            } else {
                Write-Log "⚠ Dossier de base non trouvé: $ExpandedBaseDir" -Level Warning
            }
        }
        return $true
    } else {
        $Global:FailedSoftware += $Name
        Write-Log "✗ Échec de l'installation de $Name" -Level Error
        return $false
    }
}

# Fonction pour installer un logiciel via chocolatey
function Install-SoftwareChocolatey {
    param([hashtable]$Software)
    
    $Name = $Software.name
    $PackageId = $Software.package_id
    $InstallerConfig = $Software.installer
    $BaseDirectory = $Software.base_directory
    
    # Arguments silencieux par défaut ou depuis la configuration
    $SilentArgs = if ($InstallerConfig.silent_args) { $InstallerConfig.silent_args } else { @("-y") }
    
    Write-Log "Installation de $Name..." -Level Info
    $Result = Invoke-CommandWithLog "choco" @("install", $PackageId) + $SilentArgs
    
    if ($Result.Success) {
        $Global:InstalledSoftware += $Name
        Write-Log "✓ $Name installé avec succès" -Level Info
        
        # Vérification du dossier de base
        if ($BaseDirectory) {
            $ExpandedBaseDir = Expand-PathVariables $BaseDirectory
            if (Test-Path $ExpandedBaseDir) {
                Write-Log "✓ Dossier de base vérifié: $ExpandedBaseDir" -Level Info
            } else {
                Write-Log "⚠ Dossier de base non trouvé: $ExpandedBaseDir" -Level Warning
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
        
        # Vérification du checksum si fourni
        $Checksum = $InstallerConfig.checksum
        if ($Checksum) {
            if (-not (Test-FileChecksum -FilePath $InstallerPath -ExpectedChecksum $Checksum)) {
                return $false
            }
        }
        
        # Installation
        $SilentArgs = $InstallerConfig.silent_args
        $InstallCommand = "`"$InstallerPath`" $($SilentArgs -join ' ')"
        
        Write-Log "Installation de $Name..." -Level Info
        $Result = Invoke-CommandWithLog "cmd" @("/c", $InstallCommand)
        
        if (-not $Result.Success) {
            Write-Log "✗ Échec installation $Name" -Level Error
            return $false
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
    
    # Vérification du dossier de base
    if ($BaseDirectory) {
        $ExpandedBaseDir = Expand-PathVariables $BaseDirectory
        if (Test-Path $ExpandedBaseDir) {
            Write-Log "✓ Dossier de base vérifié: $ExpandedBaseDir" -Level Info
        } else {
            Write-Log "⚠ Dossier de base non trouvé: $ExpandedBaseDir" -Level Warning
        }
    }
    
    return $true
}

# Fonction pour charger la configuration
function Get-SoftwareConfig {
    param([string]$ConfigFile)
    
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "Fichier de configuration $ConfigFile non trouvé, utilisation de la configuration par défaut" -Level Warning
        return Get-DefaultConfig
    }
    
    try {
        $ConfigContent = Get-Content -Path $ConfigFile -Raw -Encoding UTF8
        $Config = $ConfigContent | ConvertFrom-Json -AsHashtable
        $Global:Config = $Config
        $Global:BaseDirectories = $Config.base_directories
        return $Config
    }
    catch {
        Write-Log "Erreur lors du chargement de la configuration: $($_.Exception.Message)" -Level Error
        return Get-DefaultConfig
    }
}

# Fonction pour obtenir la configuration par défaut
function Get-DefaultConfig {
    return @{
        base_directories = @{
            downloads = "C:\Users\$env:USERNAME\Downloads\SoftwareInstaller"
            installers = "C:\Users\$env:USERNAME\Downloads\SoftwareInstaller\Installers"
            temp = "C:\Users\$env:USERNAME\AppData\Local\Temp\SoftwareInstaller"
            logs = "C:\Users\$env:USERNAME\Documents\SoftwareInstaller\Logs"
        }
        software_list = @(
            @{
                name = "Google Chrome"
                method = "winget"
                package_id = "Google.Chrome"
                base_directory = "C:\Program Files\Google\Chrome"
            }
        )
    }
}

# Fonction pour générer le rapport
function New-InstallationReport {
    $ReportContent = @"
=== RAPPORT D'INSTALLATION ===

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
"@
    
    $ReportContent | Out-File -FilePath $ReportFile -Encoding UTF8
    Write-Log "Rapport généré: $ReportFile" -Level Info
}

# Fonction principale
function Start-SoftwareInstallation {
    param([string]$ConfigFile)
    
    Write-Log "=== DÉMARRAGE DE L'INSTALLATION DES LOGICIELS ===" -Level Info
    
    # Vérification des privilèges administrateur
    if (-not (Test-Administrator)) {
        Write-Log "Ce script doit être exécuté en tant qu'administrateur!" -Level Error
        Write-Log "Fermeture du script..." -Level Info
        return
    }
    
    # Chargement de la configuration
    $Config = Get-SoftwareConfig -ConfigFile $ConfigFile
    $SoftwareList = $Config.software_list
    Write-Log "Configuration chargée: $($SoftwareList.Count) logiciels à installer" -Level Info
    
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
    
    # Installation via chocolatey
    if ($ChocoOk) {
        Write-Log "Installation des logiciels via chocolatey..." -Level Info
        foreach ($Software in $SoftwareList) {
            if ($Software.method -eq "chocolatey") {
                Install-SoftwareChocolatey -Software $Software
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
}

# Point d'entrée du script
try {
    Start-SoftwareInstallation -ConfigFile $ConfigFile
}
catch {
    Write-Log "Erreur fatale: $($_.Exception.Message)" -Level Error
    exit 1
}
