#Requires -Version 5.1

<#
.SYNOPSIS
    Script pour mettre à jour tous les base_directory vers D:\Utils

.DESCRIPTION
    Ce script met à jour tous les base_directory dans le fichier JSON
    pour utiliser D:\Utils avec des sous-dossiers appropriés.
#>

param(
    [string]$ConfigFile = "software_config_custom.json"
)

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

Write-ColorMessage "Mise à jour des base_directory vers D:\Utils..." -Color "Yellow"

# Charger le fichier JSON
$ConfigContent = Get-Content -Path $ConfigFile -Raw -Encoding UTF8
$Config = $ConfigContent | ConvertFrom-Json -AsHashtable

# Mapper les anciens chemins vers les nouveaux
$PathMappings = @{
    "C:\\Program Files\\" = "C:\\Utils\\"
    "C:\\Program Files (x86)\\" = "C:\\Utils\\"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\Programs\\" = "C:\\Utils\\"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\" = "C:\\Utils\\"
    "C:\\Users\\%USERNAME%\\AppData\\Roaming\\" = "C:\\Utils\\"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\Microsoft\\WindowsApps" = "C:\\Utils\\Microsoft Store Apps"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\Microsoft\\Teams" = "C:\\Utils\\Microsoft Teams"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\Discord" = "C:\\Utils\\Discord"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\slack" = "C:\\Utils\\Slack"
    "C:\\Users\\%USERNAME%\\AppData\\Roaming\\Zoom" = "C:\\Utils\\Zoom"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\NordPass" = "C:\\Utils\\NordPass"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\DBeaver" = "C:\\Utils\\DBeaver"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\LDPlayer" = "C:\\Utils\\LD Player"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\gitkraken" = "C:\\Utils\\GitKraken"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\Fotor" = "C:\\Utils\\Fotor"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\Programs\\Microsoft VS Code" = "C:\\Utils\\VS Code"
    "C:\\Users\\%USERNAME%\\AppData\\Local\\Programs\\Python\\Python311" = "C:\\Utils\\Python"
    "C:\\Users\\%USERNAME\\AppData\\Local\\Programs\\Ferdium" = "C:\\Utils\\Ferdium"
}

# Mettre à jour chaque logiciel
$UpdatedCount = 0
foreach ($Software in $Config.software_list) {
    if ($Software.base_directory) {
        $OldPath = $Software.base_directory
        $NewPath = $OldPath
        
        # Appliquer les mappings
        foreach ($Mapping in $PathMappings.GetEnumerator()) {
            if ($NewPath.StartsWith($Mapping.Key)) {
                $NewPath = $NewPath.Replace($Mapping.Key, $Mapping.Value)
                break
            }
        }
        
        # Nettoyer le chemin (enlever les variables d'environnement)
        $NewPath = $NewPath -replace '%USERNAME%', 'USER'
        
        if ($NewPath -ne $OldPath) {
            $Software.base_directory = $NewPath
            Write-ColorMessage "✓ $($Software.name): $OldPath -> $NewPath" -Color "Green"
            $UpdatedCount++
        }
    }
}

# Sauvegarder le fichier
$UpdatedConfig = $Config | ConvertTo-Json -Depth 10
$UpdatedConfig | Out-File -FilePath $ConfigFile -Encoding UTF8

Write-ColorMessage "`nMise à jour terminée ! $UpdatedCount logiciels mis à jour." -Color "Cyan"
Write-ColorMessage "Fichier sauvegarde: $ConfigFile" -Color "Info"