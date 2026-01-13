<#
    Installation automatique des addons Guild Wars (Windows)

    - Guild Wars 2 : Blish HUD, Raidcore Nexus
    - Guild Wars 1 : GW_launcher, GWToolbox++

    Le script :
    - Récupère la dernière release GitHub de chaque projet
    - Télécharge l’asset approprié (ZIP / EXE / DLL)
    - Décompresse les archives ZIP si besoin
    - Place tout dans des dossiers d’addons locaux

    Variables personnalisables (variables d’environnement ou à modifier au début du script) :
      - GW2AddonsDir : dossier cible pour les addons GW2
          Défaut : "$env:USERPROFILE\GW2Addons"
      - GW1AddonsDir : dossier cible pour les addons GW1
          Défaut : "$env:USERPROFILE\GW1Addons"

    Remarque importante :
      Le script ne connaît pas automatiquement les dossiers d’installation de GW1 / GW2.
      Il télécharge et prépare uniquement les fichiers. Vous devez ensuite copier / lier
      les DLL / EXE vers les dossiers du jeu qui conviennent (Windows natif, Steam, Proton, etc.).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info  { param($Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan }
function Write-Warn  { param($Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-ErrorMsg { param($Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Ensure-Directory {
    param(
        [Parameter(Mandatory)][string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -LiteralPath $Path | Out-Null
    }
}

# Config dossiers
$GW2AddonsDir = if ($env:GW2AddonsDir) { $env:GW2AddonsDir } else { Join-Path $env:USERPROFILE 'GW2Addons' }
$GW1AddonsDir = if ($env:GW1AddonsDir) { $env:GW1AddonsDir } else { Join-Path $env:USERPROFILE 'GW1Addons' }

Ensure-Directory -Path $GW2AddonsDir
Ensure-Directory -Path $GW1AddonsDir

Write-Info "Dossier addons GW2 : $GW2AddonsDir"
Write-Info "Dossier addons GW1 : $GW1AddonsDir"

function Get-LatestAsset {
    param(
        [Parameter(Mandatory)][string]$Repo,       # ex: blish-hud/Blish-HUD
        [Parameter(Mandatory)][string]$JqFilter,   # filtre jq-like, mais on va le reproduire en PowerShell
        [Parameter(Mandatory)][string]$OutDir
    )

    # En PowerShell, on ne dispose pas de jq, donc on filtre en objet.
    $api = "https://api.github.com/repos/$Repo/releases/latest"
    Write-Info "Récupération de la dernière release pour $Repo"

    try {
        $release = Invoke-RestMethod -Uri $api -UseBasicParsing
    } catch {
        Write-Warn "Impossible de récupérer la release GitHub pour $Repo : $($_.Exception.Message)"
        return $null
    }

    if (-not $release.assets -or $release.assets.Count -eq 0) {
        Write-Warn "Aucun asset trouvé pour $Repo"
        return $null
    }

    # Le "JqFilter" passé est en fait un pattern regex sur le nom du fichier.
    # On simplifie : on passe directement un pattern regex et on filtre sur .name
    $pattern = $JqFilter

    $asset = $release.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
    if (-not $asset) {
        Write-Warn "Aucun asset ne correspond au pattern '$pattern' pour $Repo"
        return $null
    }

    Ensure-Directory -Path $OutDir
    $fileName = $asset.name
    $outPath  = Join-Path $OutDir $fileName

    Write-Info "Téléchargement : $($asset.browser_download_url)"
    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $outPath -UseBasicParsing
    } catch {
        Write-Warn "Échec du téléchargement de $fileName : $($_.Exception.Message)"
        return $null
    }

    return $outPath
}

function Install-BlishHud {
    Write-Info "===== Blish HUD (GW2) ====="
    $targetDir = Join-Path $GW2AddonsDir 'blish-hud'
    Ensure-Directory -Path $targetDir

    # On cherche un zip nommé typiquement 'Blish HUD.zip'
    $file = Get-LatestAsset -Repo 'blish-hud/Blish-HUD' -JqFilter 'Blish HUD.*\.zip$' -OutDir $targetDir
    if (-not $file) {
        Write-Warn "Échec du téléchargement de Blish HUD"
        return
    }

    Write-Info "Décompression de $(Split-Path $file -Leaf)"
    try {
        Expand-Archive -LiteralPath $file -DestinationPath $targetDir -Force
    } catch {
        Write-Warn "Échec de la décompression de Blish HUD : $($_.Exception.Message)"
    }

    Write-Info "Blish HUD téléchargé dans : $targetDir"
    Write-Info "Copiez / configurez ce dossier en fonction de votre installation Guild Wars 2."
}

function Install-Nexus {
    Write-Info "===== Raidcore Nexus (GW2) ====="
    $targetDir = Join-Path $GW2AddonsDir 'nexus'
    Ensure-Directory -Path $targetDir

    # Nexus publie une DLL d3d11; on prend la DLL principale de la release
    $file = Get-LatestAsset -Repo 'RaidcoreGG/Nexus' -JqFilter '\.dll$' -OutDir $targetDir
    if (-not $file) {
        Write-Warn "Échec du téléchargement de Nexus"
        return
    }

    Write-Info "Nexus téléchargé dans : $targetDir"
    Write-Info "Placez la DLL (par ex. d3d11.dll) dans le dossier d'installation de Guild Wars 2."
}

function Install-GW1Launcher {
    Write-Info "===== GW_launcher (Guild Wars 1) ====="
    $targetDir = Join-Path $GW1AddonsDir 'gw-launcher'
    Ensure-Directory -Path $targetDir

    # On ne connaît pas avec certitude le dépôt GitHub public.
    # On tente quelques dépôts possibles (exemple) ; à adapter si besoin.
    $repos = @(
        'gwdevhub/GWLauncher'
        'Healix/GWLauncher'
    )

    $file = $null
    foreach ($repo in $repos) {
        Write-Info "Tentative avec le dépôt : $repo"
        $file = Get-LatestAsset -Repo $repo -JqFilter '(?i)(launcher|exe|zip)$' -OutDir $targetDir
        if ($file) { break }
    }

    if (-not $file) {
        Write-Warn "Échec du téléchargement de GW_launcher depuis les dépôts testés."
        Write-Warn "Vérifiez manuellement le dépôt GitHub ou la source officielle de GWLauncher pour Guild Wars 1."
        return
    }

    $name = Split-Path $file -Leaf
    if ($name -match '\.zip$') {
        Write-Info "Décompression de $name"
        try {
            Expand-Archive -LiteralPath $file -DestinationPath $targetDir -Force
        } catch {
            Write-Warn "Échec de la décompression de GW_launcher : $($_.Exception.Message)"
        }
    }

    Write-Info "GW_launcher téléchargé dans : $targetDir"
    Write-Info "Placez l'exécutable dans le dossier d'installation de Guild Wars 1 ou utilisez-le depuis ce dossier."
}

function Install-GW1Toolbox {
    Write-Info "===== GWToolbox++ (Guild Wars 1) ====="
    $targetDir = Join-Path $GW1AddonsDir 'gwtoolbox'
    Ensure-Directory -Path $targetDir

    # GWToolbox++ pour GW1 : dépôt gwdevhub/GWToolboxpp
    # On cherche en priorité un fichier ZIP
    $file = Get-LatestAsset -Repo 'gwdevhub/GWToolboxpp' -JqFilter '(?i)(GWToolbox.*\.zip$|.*toolbox.*\.zip$)' -OutDir $targetDir
    if (-not $file) {
        # Fallback plus large
        $file = Get-LatestAsset -Repo 'gwdevhub/GWToolboxpp' -JqFilter '(?i)(exe|zip|dll)$' -OutDir $targetDir
    }

    if (-not $file) {
        Write-Warn "Échec du téléchargement de GWToolbox++ pour Guild Wars 1."
        return
    }

    $name = Split-Path $file -Leaf
    if ($name -match '\.zip$') {
        Write-Info "Décompression de $name"
        try {
            Expand-Archive -LiteralPath $file -DestinationPath $targetDir -Force
        } catch {
            Write-Warn "Échec de la décompression de GWToolbox++ : $($_.Exception.Message)"
        }
    }

    Write-Info "GWToolbox++ (GW1) téléchargé dans : $targetDir"
    Write-Info "Copiez les fichiers requis dans le dossier de Guild Wars 1 suivant la documentation officielle."
}

function Install-GuildWarsAddons {
    Write-Info "Installation / mise à jour des addons Guild Wars"
    Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Info "Addons Guild Wars 2 : $GW2AddonsDir"
    Write-Info "Addons Guild Wars 1 : $GW1AddonsDir"
    Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host ""

    Write-Info ">>> Installation des addons Guild Wars 2 <<<"
    Install-BlishHud
    Install-Nexus

    Write-Host ""
    Write-Info ">>> Installation des addons Guild Wars 1 <<<"
    Install-GW1Launcher
    Install-GW1Toolbox

    Write-Host ""
    Write-Info "Terminé."
}

Install-GuildWarsAddons

