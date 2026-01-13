#!/usr/bin/env bash

# Installation automatique des addons Guild Wars :
# - Guild Wars 2 : Blish HUD, Raidcore Nexus
# - Guild Wars 1 : GW_launcher, GWToolbox++
#
# Le script télécharge toujours la **dernière release** GitHub de chaque projet
# et place les fichiers dans un dossier local d'addons.
# 
# Variables personnalisables :
#   GW2_ADDONS_DIR : dossier cible pour les addons GW2
#     défaut : "$HOME/GW2Addons"
#   GW1_ADDONS_DIR : dossier cible pour les addons GW1
#     défaut : "$HOME/GW1Addons"
#
# Remarque importante :
#   Ce script ne connaît pas automatiquement le dossier d'installation de GW1/GW2
#   (sous Windows ou Proton). Vous devrez copier / lier les DLL / exécutables
#   depuis les dossiers d'addons vers le répertoire du jeu qui convient.

set -euo pipefail

GW2_ADDONS_DIR="${GW2_ADDONS_DIR:-"$HOME/GW2Addons"}"
GW1_ADDONS_DIR="${GW1_ADDONS_DIR:-"$HOME/GW1Addons"}"
mkdir -p "$GW2_ADDONS_DIR"
mkdir -p "$GW1_ADDONS_DIR"

log_info()  { echo -e "[INFO]  $*"; }
log_warn()  { echo -e "[WARN]  $*"; }
log_error() { echo -e "[ERROR] $*" >&2; }

require_cmd() {
  local cmd="$1"
  local pkg="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    if [[ -n "$pkg" ]]; then
      log_info "Installation de la dépendance manquante : $pkg (pour $cmd)"
      sudo apt update && sudo apt install -y "$pkg"
    else
      log_error "Commande requise manquante : $cmd"
      exit 1
    fi
  fi
}

log_info "Dossier de destination des addons GW2 : $GW2_ADDONS_DIR"
log_info "Dossier de destination des addons GW1 : $GW1_ADDONS_DIR"

# Dépendances nécessaires
require_cmd curl curl
require_cmd jq   jq
require_cmd unzip unzip

download_latest_asset() {
  local repo="$1"         # ex: blish-hud/Blish-HUD
  local jq_filter="$2"    # filtre jq pour sélectionner l'asset
  local out_dir="$3"      # dossier de destination

  log_info "Récupération de la dernière release pour $repo"

  local api="https://api.github.com/repos/$repo/releases/latest"
  local asset_url
  asset_url="$(curl -fsSL "$api" | jq -r "$jq_filter" | head -n1 || true)"

  if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
    log_warn "Aucun asset correspondant trouvé pour $repo"
    return 1
  fi

  mkdir -p "$out_dir"
  local filename
  filename="$(basename "$asset_url")"

  log_info "Téléchargement : $asset_url"
  curl -fL "$asset_url" -o "$out_dir/$filename"

  echo "$out_dir/$filename"
}

install_blish_hud() {
  log_info "===== Blish HUD ====="
  local target_dir="$GW2_ADDONS_DIR/blish-hud"
  mkdir -p "$target_dir"

  # On cherche un zip nommé typiquement 'Blish HUD.zip'
  local file
  file="$(download_latest_asset \
    "blish-hud/Blish-HUD" \
    '.assets[] | select(.name | test("Blish HUD.*\\.zip$")) | .browser_download_url' \
    "$target_dir")" || {
      log_warn "Échec du téléchargement de Blish HUD"
      return
    }

  log_info "Décompression de $(basename "$file")"
  unzip -o "$file" -d "$target_dir"

  log_info "Blish HUD téléchargé dans : $target_dir"
  log_info "Copiez / configurez ce dossier en fonction de votre installation GW2."
}

install_nexus() {
  log_info "===== Raidcore Nexus ====="
  local target_dir="$GW2_ADDONS_DIR/nexus"
  mkdir -p "$target_dir"

  # Nexus publie une DLL d3d11; on prend la DLL principale de la release
  local file
  file="$(download_latest_asset \
    "RaidcoreGG/Nexus" \
    '.assets[] | select(.name | test("\\\\.dll$")) | .browser_download_url' \
    "$target_dir")" || {
      log_warn "Échec du téléchargement de Nexus"
      return
    }

  log_info "Nexus téléchargé dans : $target_dir"
  log_info "Placez la DLL (par ex. d3d11.dll) dans le dossier d'installation de Guild Wars 2."
}

install_gw1_launcher() {
  log_info "===== GW_launcher (Guild Wars 1) ====="
  local target_dir="$GW1_ADDONS_DIR/gw-launcher"
  mkdir -p "$target_dir"

  # GWLauncher peut être disponible sous différents noms de dépôt
  # On essaie plusieurs dépôts possibles
  local file
  local repos=("gwdevhub/GWLauncher" "Healix/GWLauncher")
  local found=false

  for repo in "${repos[@]}"; do
    log_info "Tentative avec le dépôt : $repo"
    if file="$(download_latest_asset \
      "$repo" \
      '.assets[] | select(.name | test("(?i)(launcher|exe|zip)$")) | .browser_download_url' \
      "$target_dir" 2>/dev/null)"; then
      found=true
      break
    fi
  done

  if [[ "$found" == false ]]; then
    log_warn "Échec du téléchargement de GW_launcher depuis les dépôts testés"
    log_warn "Vérifiez manuellement le dépôt GitHub de GWLauncher pour Guild Wars 1"
    log_warn "Le dépôt peut avoir un nom différent ou ne pas être disponible publiquement"
    return
  fi

  local name
  name="$(basename "$file")"
  if [[ "$name" =~ \.zip$ ]]; then
    log_info "Décompression de $name"
    unzip -o "$file" -d "$target_dir"
  fi

  log_info "GW_launcher téléchargé dans : $target_dir"
  log_info "Placez l'exécutable dans le dossier d'installation de Guild Wars 1 ou utilisez-le depuis ce dossier."
}

install_gw1_toolbox() {
  log_info "===== GWToolbox++ (Guild Wars 1) ====="
  local target_dir="$GW1_ADDONS_DIR/gwtoolbox"
  mkdir -p "$target_dir"

  # GWToolbox++ pour GW1 est sur gwdevhub/GWToolboxpp
  # On cherche d'abord un fichier zip, sinon on prend n'importe quel asset
  local file
  file="$(download_latest_asset \
    "gwdevhub/GWToolboxpp" \
    '.assets[] | select(.name | test("(?i)(GWToolbox.*\\.zip$|.*toolbox.*\\.zip$)")) | .browser_download_url' \
    "$target_dir" 2>/dev/null)" || {
      # Si pas de zip trouvé, on essaie avec un filtre plus large
      file="$(download_latest_asset \
        "gwdevhub/GWToolboxpp" \
        '.assets[] | select(.name | test("(?i)(exe|zip|dll)$")) | .browser_download_url' \
        "$target_dir")" || {
          log_warn "Échec du téléchargement de GWToolbox++ pour GW1"
          return
        }
    }

  local name
  name="$(basename "$file")"
  if [[ "$name" =~ \.zip$ ]]; then
    log_info "Décompression de $name"
    unzip -o "$file" -d "$target_dir"
  fi

  log_info "GWToolbox++ (GW1) téléchargé dans : $target_dir"
  log_info "Copiez les fichiers requis dans le dossier de Guild Wars 1 suivant la documentation officielle."
}

main() {
  log_info "Installation / mise à jour des addons Guild Wars"
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "Addons Guild Wars 2 : $GW2_ADDONS_DIR"
  log_info "Addons Guild Wars 1 : $GW1_ADDONS_DIR"
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  log_info ""
  log_info ">>> Installation des addons Guild Wars 2 <<<"
  install_blish_hud
  install_nexus

  log_info ""
  log_info ">>> Installation des addons Guild Wars 1 <<<"
  install_gw1_launcher
  install_gw1_toolbox

  log_info ""
  log_info "Terminé."
}

main "$@"
