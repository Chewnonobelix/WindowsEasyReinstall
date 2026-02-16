#!/bin/bash

# Script d'installation de paquets depuis un fichier JSON
# Ordre de priorité: install_command (JSON) -> apt -> snap

set -uo pipefail
# Note: on n'utilise pas set -e car les fonctions d'installation retournent
# explicitement 0/1 et sont toujours appelées dans un contexte if/&&/||

# ─────────────────────────────────────────────
# Couleurs et logs
# ─────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ─────────────────────────────────────────────
# Prérequis
# ─────────────────────────────────────────────

# Vérifier que jq est installé
if ! command -v jq &> /dev/null; then
    log_info "jq n'est pas installé. Installation..."
    sudo apt update && sudo apt install -y jq || { log_error "Impossible d'installer jq."; exit 1; }
fi

# Vérifier les arguments
if [ $# -eq 0 ]; then
    log_error "Usage: $0 <fichier_config.json>"
    exit 1
fi

CONFIG_FILE="$1"

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Le fichier $CONFIG_FILE n'existe pas."
    exit 1
fi

# Valider le JSON
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    log_error "Le fichier $CONFIG_FILE n'est pas un JSON valide."
    exit 1
fi

log_info "Lecture du fichier de configuration: $CONFIG_FILE"

# ─────────────────────────────────────────────
# Fonctions d'installation
# ─────────────────────────────────────────────

# FIX: install_via_apt ne fait plus de apt update (fait une seule fois globalement)
install_via_apt() {
    local package_name="$1"
    log_info "Tentative d'installation via apt: $package_name"

    if sudo apt install -y "$package_name" 2>/dev/null; then
        log_success "Paquet $package_name installé via apt"
        return 0
    else
        log_warning "Échec de l'installation via apt pour $package_name"
        return 1
    fi
}

# FIX: install_via_snap tente d'abord sans --classic, puis avec si nécessaire
install_via_snap() {
    local package_name="$1"
    log_info "Tentative d'installation via snap: $package_name"

    if sudo snap install "$package_name" 2>/dev/null; then
        log_success "Paquet $package_name installé via snap"
        return 0
    elif sudo snap install "$package_name" --classic 2>/dev/null; then
        log_success "Paquet $package_name installé via snap (--classic)"
        return 0
    else
        log_warning "Échec de l'installation via snap pour $package_name"
        return 1
    fi
}

# FIX: utilise un sous-shell pour isoler le cd, et gère le cleanup localement
install_via_custom() {
    local package_info="$1"
    local package_name
    local download_url
    local install_command

    package_name=$(echo "$package_info"    | jq -r '.name            // empty')
    download_url=$(echo "$package_info"    | jq -r '.download_url    // empty')
    install_command=$(echo "$package_info" | jq -r '.install_command // empty')

    if [ -z "$download_url" ] && [ -z "$install_command" ]; then
        log_warning "Aucune URL ou commande d'installation pour $package_name"
        return 1
    fi

    # FIX: tout le travail de téléchargement se passe dans un sous-shell
    # → le cd n'affecte pas le répertoire courant du script parent
    (
        # FIX: trap local au sous-shell uniquement
        TEMP_DIR=$(mktemp -d)
        trap 'rm -rf "$TEMP_DIR"' EXIT

        cd "$TEMP_DIR"

        if [ -n "$download_url" ]; then
            log_info "Téléchargement depuis: $download_url"

            if wget -q "$download_url" -O downloaded_file 2>/dev/null \
               || curl -sL "$download_url" -o downloaded_file 2>/dev/null; then

                log_success "Fichier téléchargé avec succès"

                if [[ "$download_url" == *.deb ]] || file downloaded_file 2>/dev/null | grep -q "Debian"; then
                    log_info "Installation du paquet .deb"
                    sudo dpkg -i downloaded_file && sudo apt-get install -f -y
                    log_success "Paquet $package_name installé (.deb)"
                    exit 0

                elif [[ "$download_url" == *.AppImage ]] || file downloaded_file 2>/dev/null | grep -qi "appimage"; then
                    log_info "Fichier AppImage détecté"
                    chmod +x downloaded_file
                    mkdir -p "$HOME/.local/bin"
                    mv downloaded_file "$HOME/.local/bin/$package_name"
                    # Créer un .desktop entry minimal
                    mkdir -p "$HOME/.local/share/applications"
                    printf '[Desktop Entry]\nName=%s\nExec=%s\nType=Application\nCategories=Application;\n' \
                        "$package_name" "$HOME/.local/bin/$package_name" \
                        > "$HOME/.local/share/applications/${package_name}.desktop"
                    log_success "Paquet $package_name installé (AppImage -> ~/.local/bin/)"
                    exit 0

                elif [[ "$download_url" == *.sh ]]; then
                    log_info "Script shell détecté"
                    chmod +x downloaded_file
                    bash downloaded_file
                    log_success "Paquet $package_name installé (script shell)"
                    exit 0

                else
                    log_warning "Type de fichier non reconnu pour $download_url"
                fi
            else
                log_error "Échec du téléchargement depuis $download_url"
                exit 1
            fi
        fi

        if [ -n "$install_command" ]; then
            log_info "Exécution de la commande d'installation personnalisée..."
            if eval "$install_command"; then
                log_success "Paquet $package_name installé via commande personnalisée"
                exit 0
            else
                log_error "Échec de la commande d'installation pour $package_name"
                exit 1
            fi
        fi

        exit 1
    )
    return $?
}

# ─────────────────────────────────────────────
# Fonction principale d'installation
# FIX: respecte l'ordre install_command > apt > snap
# ─────────────────────────────────────────────

install_package() {
    local package_info="$1"
    local package_name
    local install_command

    package_name=$(echo "$package_info"    | jq -r '.name            // empty')
    install_command=$(echo "$package_info" | jq -r '.install_command // empty')

    if [ -z "$package_name" ]; then
        log_error "Nom de paquet manquant dans la configuration"
        return 1
    fi

    log_section
    log_info "Installation de: $package_name"
    log_section

    # Vérifier si déjà installé
    if dpkg -l 2>/dev/null | grep -q "^ii[[:space:]]*${package_name}[[:space:]]"; then
        log_success "$package_name est déjà installé (apt/dpkg)"
        return 0
    fi
    if snap list 2>/dev/null | grep -q "^${package_name}[[:space:]]"; then
        log_success "$package_name est déjà installé (snap)"
        return 0
    fi
    if command -v "$package_name" &>/dev/null; then
        log_success "$package_name est déjà disponible dans le PATH"
        return 0
    fi

    # FIX: si install_command est défini dans le JSON → l'utiliser directement
    # sans tenter apt ou snap avant (évite des installations incorrectes ou
    # des snaps sans --classic)
    if [ -n "$install_command" ]; then
        log_info "Utilisation de la commande définie dans le JSON..."
        if install_via_custom "$package_info"; then
            return 0
        fi
        log_error "Impossible d'installer $package_name"
        return 1
    fi

    # Sinon fallback: apt → snap
    if install_via_apt "$package_name"; then
        return 0
    fi

    if install_via_snap "$package_name"; then
        return 0
    fi

    log_error "Impossible d'installer $package_name avec aucune méthode"
    return 1
}

# ─────────────────────────────────────────────
# Configuration SSH + clonage GitHub
# ─────────────────────────────────────────────

setup_ssh_key() {
    log_section
    log_info "Configuration de la clé SSH pour GitHub"
    log_section

    local SSH_KEY_NAME="id_ed25519_github"
    local SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
    local SSH_PUB_KEY_PATH="${SSH_KEY_PATH}.pub"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Clé existante
    if [ -f "$SSH_PUB_KEY_PATH" ]; then
        log_info "Une clé SSH existe déjà: $SSH_PUB_KEY_PATH"
        read -p "Voulez-vous utiliser cette clé existante? (O/n): " USE_EXISTING
        if [[ ! "$USE_EXISTING" =~ ^[Nn]$ ]]; then
            log_info "Utilisation de la clé existante:"
            echo ""
            cat "$SSH_PUB_KEY_PATH"
            echo ""
            _configure_ssh_host "$SSH_KEY_PATH"
            return 0
        fi
        # Supprimer l'ancienne clé pour en générer une nouvelle
        rm -f "$SSH_KEY_PATH" "$SSH_PUB_KEY_PATH"
    fi

    # Email
    echo ""
    read -p "Entrez votre email GitHub (pour la clé SSH): " GITHUB_EMAIL
    if [ -z "$GITHUB_EMAIL" ]; then
        GITHUB_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
    fi
    if [ -z "$GITHUB_EMAIL" ]; then
        GITHUB_EMAIL="user@github.com"
        log_warning "Aucun email fourni, utilisation de: $GITHUB_EMAIL"
    fi

    # FIX: on supprime la clé existante avant de générer (pas besoin de <<< "y")
    log_info "Génération de la clé SSH Ed25519..."
    if ! ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f "$SSH_KEY_PATH" -N "" 2>/dev/null; then
        log_error "Échec de la génération de la clé SSH"
        return 1
    fi

    log_success "Clé SSH générée: $SSH_PUB_KEY_PATH"
    echo ""
    log_info "Clé publique générée:"
    log_section
    cat "$SSH_PUB_KEY_PATH"
    echo ""
    log_section

    # Ajout automatique via API GitHub
    echo ""
    read -p "Voulez-vous ajouter cette clé à votre compte GitHub via l'API? (O/n): " ADD_TO_GITHUB

    if [[ ! "$ADD_TO_GITHUB" =~ ^[Nn]$ ]]; then
        echo ""
        log_info "Créez un token (permission 'admin:public_key') sur:"
        log_info "https://github.com/settings/tokens"
        echo ""
        read -p "Token GitHub (Entrée = ajout manuel): " GITHUB_TOKEN

        if [ -n "$GITHUB_TOKEN" ]; then
            local SSH_PUB_KEY
            SSH_PUB_KEY=$(cat "$SSH_PUB_KEY_PATH")
            local KEY_TITLE="UbuntuConfig-$(hostname)-$(date +%Y%m%d)"

            log_info "Ajout de la clé via l'API GitHub..."
            local API_RESPONSE
            API_RESPONSE=$(curl -s -X POST \
                -H "Authorization: token $GITHUB_TOKEN" \
                -H "Accept: application/vnd.github.v3+json" \
                https://api.github.com/user/keys \
                -d "{\"title\":\"$KEY_TITLE\",\"key\":\"$SSH_PUB_KEY\"}")

            if echo "$API_RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
                local KEY_ID
                KEY_ID=$(echo "$API_RESPONSE" | jq -r '.id')
                log_success "Clé SSH ajoutée à GitHub (ID: $KEY_ID)"
            else
                local ERROR_MSG
                ERROR_MSG=$(echo "$API_RESPONSE" | jq -r '.message // "Erreur inconnue"' 2>/dev/null)
                log_error "Échec de l'ajout automatique: $ERROR_MSG"
                _print_manual_github_instructions
            fi
        else
            _print_manual_github_instructions
        fi
    else
        _print_manual_github_instructions
    fi

    _configure_ssh_host "$SSH_KEY_PATH"
}

_print_manual_github_instructions() {
    log_info "Ajoutez manuellement la clé à votre compte GitHub:"
    log_info "  1. Allez sur https://github.com/settings/keys"
    log_info "  2. Cliquez sur 'New SSH key'"
    log_info "  3. Collez le contenu de la clé publique ci-dessus"
    echo ""
    read -p "Appuyez sur Entrée après avoir ajouté la clé..."
}

_configure_ssh_host() {
    local SSH_KEY_PATH="$1"
    local SSH_CONFIG="$HOME/.ssh/config"

    if [ -f "$SSH_CONFIG" ] && grep -q "Host github.com" "$SSH_CONFIG"; then
        log_info "Configuration SSH GitHub déjà présente dans $SSH_CONFIG"
    else
        {
            echo ""
            echo "Host github.com"
            echo "    HostName github.com"
            echo "    User git"
            echo "    IdentityFile $SSH_KEY_PATH"
            echo "    IdentitiesOnly yes"
        } >> "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
        log_success "Configuration SSH ajoutée pour github.com"
    fi

    # Test de connexion
    log_info "Test de la connexion SSH à GitHub..."
    local SSH_OUTPUT
    SSH_OUTPUT=$(ssh -T git@github.com -o StrictHostKeyChecking=no -o ConnectTimeout=5 2>&1 || true)

    if echo "$SSH_OUTPUT" | grep -qiE "successfully authenticated"; then
        log_success "Connexion SSH à GitHub réussie !"
    else
        log_warning "Test SSH non concluant (normal si la clé vient d'être ajoutée)"
        log_info "Vous pouvez tester manuellement: ssh -T git@github.com"
    fi
    echo ""
}

clone_github_repos() {
    log_section
    log_info "Clonage des dépôts GitHub"
    log_section

    echo ""
    read -p "Nom d'utilisateur GitHub (Entrée = ignorer): " GITHUB_USERNAME
    [ -z "$GITHUB_USERNAME" ] && { log_info "Clonage GitHub ignoré."; return 0; }

    echo ""
    read -p "Répertoire de destination (défaut: $HOME/github): " CLONE_DIR
    CLONE_DIR="${CLONE_DIR:-$HOME/github}"
    mkdir -p "$CLONE_DIR"
    log_info "Répertoire de clonage: $CLONE_DIR"

    # Prérequis
    command -v curl &>/dev/null || sudo apt install -y curl
    command -v git  &>/dev/null || sudo apt install -y git

    # Génération de la clé SSH
    setup_ssh_key

    # Récupération des dépôts (avec pagination)
    log_info "Récupération de la liste des dépôts pour $GITHUB_USERNAME..."
    local REPOS_JSON="[]"
    local PAGE=1
    local PER_PAGE=100

    while true; do
        local PAGE_JSON
        PAGE_JSON=$(curl -s "https://api.github.com/users/$GITHUB_USERNAME/repos?per_page=$PER_PAGE&page=$PAGE" 2>/dev/null || echo "")

        if [ -z "$PAGE_JSON" ]; then
            log_error "Impossible de récupérer les dépôts (pas de réponse)"
            return 1
        fi

        if echo "$PAGE_JSON" | jq -e '.message' > /dev/null 2>&1; then
            local ERR
            ERR=$(echo "$PAGE_JSON" | jq -r '.message')
            log_error "Erreur GitHub API: $ERR"
            return 1
        fi

        local PAGE_COUNT
        PAGE_COUNT=$(echo "$PAGE_JSON" | jq '. | length')

        [ "$PAGE_COUNT" -eq 0 ] && break

        REPOS_JSON=$(echo "$REPOS_JSON" "$PAGE_JSON" | jq -s '.[0] + .[1]')

        [ "$PAGE_COUNT" -lt "$PER_PAGE" ] && break
        PAGE=$((PAGE + 1))
    done

    local REPO_COUNT
    REPO_COUNT=$(echo "$REPOS_JSON" | jq '. | length')

    if [ "$REPO_COUNT" -eq 0 ]; then
        log_warning "Aucun dépôt public trouvé pour $GITHUB_USERNAME"
        return 0
    fi

    log_info "Dépôts trouvés: $REPO_COUNT"
    echo ""

    # Compteurs via fichier temporaire (persiste dans la boucle while)
    local TEMP_COUNTERS
    TEMP_COUNTERS=$(mktemp)
    echo "0|0|0" > "$TEMP_COUNTERS"
    local TEMP_FAILED_REPOS
    TEMP_FAILED_REPOS=$(mktemp)

    local CLONE_TOTAL=0
    while IFS='|' read -r repo_name clone_url_https is_private ssh_url; do
        CLONE_TOTAL=$((CLONE_TOTAL + 1))
        local REPO_DIR="$CLONE_DIR/$repo_name"

        log_section
        log_info "[$CLONE_TOTAL/$REPO_COUNT] $repo_name$([ "$is_private" = "true" ] && echo " (privé)" || echo "")"

        local CLONE_URL="$clone_url_https"
        if [ "$is_private" = "true" ] && [ -n "$ssh_url" ] && [ "$ssh_url" != "null" ]; then
            CLONE_URL="$ssh_url"
            log_info "Utilisation de SSH (dépôt privé)"
        fi

        if [ -d "$REPO_DIR" ]; then
            log_warning "Le dépôt $repo_name existe déjà dans $REPO_DIR"
            read -p "Mettre à jour? (o/N): " UPDATE_REPO
            if [[ "$UPDATE_REPO" =~ ^[Oo]$ ]]; then
                local SAVED_DIR="$PWD"
                cd "$REPO_DIR"
                if git pull 2>/dev/null; then
                    log_success "Dépôt $repo_name mis à jour"
                    IFS='|' read -r s sk f < "$TEMP_COUNTERS"; echo "$((s+1))|$sk|$f" > "$TEMP_COUNTERS"
                else
                    log_error "Échec de la mise à jour de $repo_name"
                    IFS='|' read -r s sk f < "$TEMP_COUNTERS"; echo "$s|$sk|$((f+1))" > "$TEMP_COUNTERS"
                    echo "$repo_name (mise à jour)" >> "$TEMP_FAILED_REPOS"
                fi
                cd "$SAVED_DIR"
            else
                log_info "Ignoré"
                IFS='|' read -r s sk f < "$TEMP_COUNTERS"; echo "$s|$((sk+1))|$f" > "$TEMP_COUNTERS"
            fi
        else
            if git clone "$CLONE_URL" "$REPO_DIR" 2>/dev/null; then
                log_success "Dépôt $repo_name cloné"
                IFS='|' read -r s sk f < "$TEMP_COUNTERS"; echo "$((s+1))|$sk|$f" > "$TEMP_COUNTERS"
            else
                log_error "Échec du clonage de $repo_name"
                [ "$is_private" = "true" ] && log_warning "Vérifiez que la clé SSH est bien configurée pour les dépôts privés"
                IFS='|' read -r s sk f < "$TEMP_COUNTERS"; echo "$s|$sk|$((f+1))" > "$TEMP_COUNTERS"
                echo "$repo_name" >> "$TEMP_FAILED_REPOS"
            fi
        fi
        echo ""
    done < <(echo "$REPOS_JSON" | jq -r '.[] | "\(.name)|\(.clone_url)|\(.private)|\(.ssh_url)"')

    local CLONE_SUCCESS CLONE_SKIPPED CLONE_FAILED
    IFS='|' read -r CLONE_SUCCESS CLONE_SKIPPED CLONE_FAILED < "$TEMP_COUNTERS"
    rm -f "$TEMP_COUNTERS"

    log_section
    log_info "Résumé clonage GitHub:"
    log_info "  Utilisateur : $GITHUB_USERNAME"
    log_info "  Répertoire  : $CLONE_DIR"
    log_info "  Total       : $REPO_COUNT"
    log_success "  Clonés/MAJ  : $CLONE_SUCCESS"
    [ "$CLONE_SKIPPED" -gt 0 ] && log_warning "  Ignorés     : $CLONE_SKIPPED"
    if [ "$CLONE_FAILED" -gt 0 ]; then
        log_error "  Échoués     : $CLONE_FAILED"
        log_section
        log_error "Dépôts en échec :"
        while IFS= read -r failed_repo; do
            log_error "  ✗ $failed_repo"
        done < "$TEMP_FAILED_REPOS"
    fi
    rm -f "$TEMP_FAILED_REPOS"
    log_section
}

# ─────────────────────────────────────────────
# Main: installation des paquets
# ─────────────────────────────────────────────

log_info "Mise à jour des dépôts apt..."
sudo apt update

PACKAGES=$(jq -c '.packages[]' "$CONFIG_FILE" 2>/dev/null || echo "")

if [ -z "$PACKAGES" ]; then
    log_error "Aucun paquet trouvé dans $CONFIG_FILE (format invalide ou liste vide)"
    exit 1
fi

# Initialiser les compteurs et la liste des échecs
TOTAL=0
SUCCESS=0
FAILED=0
FAILED_PACKAGES=()

while IFS= read -r package_info; do
    TOTAL=$((TOTAL + 1))
    pkg_name=$(echo "$package_info" | jq -r '.name // empty')
    if install_package "$package_info"; then
        SUCCESS=$((SUCCESS + 1))
    else
        FAILED=$((FAILED + 1))
        FAILED_PACKAGES+=("$pkg_name")
    fi
    echo ""
done <<< "$PACKAGES"

log_section
log_info "Résumé de l'installation:"
log_info "  Total   : $TOTAL"
log_success "  Réussis : $SUCCESS"
if [ "$FAILED" -gt 0 ]; then
    log_error "  Échoués : $FAILED"
    log_section
    log_error "Paquets en échec :"
    for pkg in "${FAILED_PACKAGES[@]}"; do
        log_error "  ✗ $pkg"
    done
fi
log_section

# ─────────────────────────────────────────────
# Clonage GitHub (optionnel)
# ─────────────────────────────────────────────

echo ""
read -p "Voulez-vous cloner des dépôts GitHub? (o/N): " CLONE_GITHUB
[[ "$CLONE_GITHUB" =~ ^[Oo]$ ]] && clone_github_repos

# Exit code reflète les échecs d'installation
[ "$FAILED" -gt 0 ] && exit 1
exit 0
