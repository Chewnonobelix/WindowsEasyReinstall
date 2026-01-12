#!/bin/bash

# Script d'installation de paquets depuis un fichier JSON
# Ordre de priorité: apt -> snap -> téléchargement direct

set -euo pipefail

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier que jq est installé
if ! command -v jq &> /dev/null; then
    log_error "jq n'est pas installé. Installation..."
    sudo apt update && sudo apt install -y jq
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

log_info "Lecture du fichier de configuration: $CONFIG_FILE"

# Fonction pour installer via apt
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

# Fonction pour installer via snap
install_via_snap() {
    local package_name="$1"
    log_info "Tentative d'installation via snap: $package_name"
    
    if sudo snap install "$package_name" 2>/dev/null; then
        log_success "Paquet $package_name installé via snap"
        return 0
    else
        log_warning "Échec de l'installation via snap pour $package_name"
        return 1
    fi
}

# Fonction pour télécharger et installer directement
install_via_download() {
    local package_info="$1"
    local package_name=$(echo "$package_info" | jq -r '.name // empty')
    local download_url=$(echo "$package_info" | jq -r '.download_url // empty')
    local install_command=$(echo "$package_info" | jq -r '.install_command // empty')
    
    if [ -z "$download_url" ] && [ -z "$install_command" ]; then
        log_warning "Aucune URL de téléchargement ou commande d'installation spécifiée pour $package_name"
        return 1
    fi
    
    log_info "Tentative de téléchargement direct pour: $package_name"
    
    # Créer un répertoire temporaire
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    cd "$TEMP_DIR"
    
    # Si une URL est fournie, télécharger le fichier
    if [ -n "$download_url" ]; then
        log_info "Téléchargement depuis: $download_url"
        if wget -q "$download_url" -O downloaded_file || curl -sL "$download_url" -o downloaded_file; then
            log_success "Fichier téléchargé avec succès"
            
            # Détecter le type de fichier et installer
            if [[ "$download_url" == *.deb ]]; then
                log_info "Installation du paquet .deb"
                sudo dpkg -i downloaded_file || sudo apt-get install -f -y
                log_success "Paquet $package_name installé via téléchargement direct (.deb)"
                return 0
            elif [[ "$download_url" == *.AppImage ]]; then
                log_info "Fichier AppImage détecté"
                chmod +x downloaded_file
                # Déplacer vers un répertoire approprié (optionnel)
                if [ -n "$package_name" ]; then
                    # Créer ~/.local/bin s'il n'existe pas
                    mkdir -p "$HOME/.local/bin"
                    sudo mv downloaded_file "/usr/local/bin/$package_name" 2>/dev/null || mv downloaded_file "$HOME/.local/bin/$package_name"
                    log_success "Paquet $package_name installé via téléchargement direct (AppImage)"
                    return 0
                fi
            elif [[ "$download_url" == *.sh ]]; then
                log_info "Script shell détecté"
                chmod +x downloaded_file
                sudo bash downloaded_file || bash downloaded_file
                log_success "Paquet $package_name installé via téléchargement direct (script)"
                return 0
            else
                log_warning "Type de fichier non reconnu pour $download_url"
            fi
        else
            log_error "Échec du téléchargement depuis $download_url"
            return 1
        fi
    fi
    
    # Si une commande d'installation est fournie, l'exécuter
    if [ -n "$install_command" ]; then
        log_info "Exécution de la commande d'installation: $install_command"
        if eval "$install_command"; then
            log_success "Paquet $package_name installé via commande personnalisée"
            return 0
        else
            log_error "Échec de la commande d'installation"
            return 1
        fi
    fi
    
    return 1
}

# Fonction principale d'installation
install_package() {
    local package_info="$1"
    local package_name=$(echo "$package_info" | jq -r '.name // empty')
    
    if [ -z "$package_name" ]; then
        log_error "Nom de paquet manquant dans la configuration"
        return 1
    fi
    
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Installation de: $package_name"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Vérifier si le paquet est déjà installé
    local installed=false
    
    # Vérifier via apt
    if dpkg -l | grep -q "^ii.*$package_name"; then
        log_info "Paquet $package_name déjà installé via apt"
        installed=true
    fi
    
    # Vérifier via snap
    if snap list 2>/dev/null | grep -q "^$package_name"; then
        log_info "Paquet $package_name déjà installé via snap"
        installed=true
    fi
    
    if [ "$installed" = true ]; then
        log_success "Paquet $package_name déjà installé, passage au suivant"
        return 0
    fi
    
    # Essayer apt en premier
    if install_via_apt "$package_name"; then
        return 0
    fi
    
    # Essayer snap en deuxième
    if install_via_snap "$package_name"; then
        return 0
    fi
    
    # Essayer le téléchargement direct en dernier
    if install_via_download "$package_info"; then
        return 0
    fi
    
    log_error "Impossible d'installer $package_name avec aucune méthode"
    return 1
}

# Mettre à jour les dépôts apt
log_info "Mise à jour des dépôts apt..."
sudo apt update

# Lire et traiter le fichier JSON
PACKAGES=$(jq -c '.packages[]' "$CONFIG_FILE" 2>/dev/null)

if [ -z "$PACKAGES" ]; then
    log_error "Aucun paquet trouvé dans le fichier de configuration ou format JSON invalide"
    exit 1
fi

# Compteurs
TOTAL=0
SUCCESS=0
FAILED=0

# Traiter chaque paquet
while IFS= read -r package_info; do
    TOTAL=$((TOTAL + 1))
    if install_package "$package_info"; then
        SUCCESS=$((SUCCESS + 1))
    else
        FAILED=$((FAILED + 1))
    fi
    echo ""
done <<< "$PACKAGES"

# Résumé
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "Résumé de l'installation:"
log_info "  Total: $TOTAL"
log_success "  Réussis: $SUCCESS"
if [ $FAILED -gt 0 ]; then
    log_error "  Échoués: $FAILED"
fi
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

# Fonction pour cloner les dépôts GitHub
clone_github_repos() {
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Clonage des dépôts GitHub"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Demander le nom d'utilisateur GitHub
    echo ""
    read -p "Entrez le nom d'utilisateur GitHub (ou appuyez sur Entrée pour ignorer): " GITHUB_USERNAME
    
    if [ -z "$GITHUB_USERNAME" ]; then
        log_info "Clonage GitHub ignoré."
        return 0
    fi
    
    # Demander où cloner les dépôts
    echo ""
    read -p "Où voulez-vous cloner les dépôts? (défaut: $HOME/github): " CLONE_DIR
    
    if [ -z "$CLONE_DIR" ]; then
        CLONE_DIR="$HOME/github"
    fi
    
    # Créer le répertoire s'il n'existe pas
    mkdir -p "$CLONE_DIR"
    
    log_info "Répertoire de clonage: $CLONE_DIR"
    
    # Vérifier que curl est disponible
    if ! command -v curl &> /dev/null; then
        log_error "curl n'est pas installé. Installation..."
        sudo apt install -y curl
    fi
    
    # Vérifier que git est disponible
    if ! command -v git &> /dev/null; then
        log_error "git n'est pas installé. Installation..."
        sudo apt install -y git
    fi
    
    # Fonction pour générer et ajouter la clé SSH à GitHub
    setup_ssh_key() {
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "Configuration de la clé SSH pour GitHub"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        SSH_KEY_NAME="id_ed25519_github"
        SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
        SSH_PUB_KEY_PATH="$SSH_KEY_PATH.pub"
        
        # Vérifier si une clé SSH existe déjà
        if [ -f "$SSH_PUB_KEY_PATH" ]; then
            log_info "Une clé SSH existe déjà: $SSH_PUB_KEY_PATH"
            read -p "Voulez-vous utiliser cette clé existante? (O/n): " USE_EXISTING
            if [[ ! "$USE_EXISTING" =~ ^[Nn]$ ]]; then
                log_info "Utilisation de la clé existante"
                cat "$SSH_PUB_KEY_PATH"
                echo ""
                read -p "Appuyez sur Entrée après avoir ajouté cette clé à votre compte GitHub..."
                return 0
            fi
        fi
        
        # Demander l'email pour la clé SSH
        echo ""
        read -p "Entrez votre email GitHub (pour la clé SSH): " GITHUB_EMAIL
        
        if [ -z "$GITHUB_EMAIL" ]; then
            log_warning "Email non fourni, utilisation de l'email Git configuré ou génération sans email"
            GITHUB_EMAIL=$(git config user.email 2>/dev/null || echo "")
        fi
        
        # Générer la clé SSH
        log_info "Génération de la clé SSH..."
        
        # Créer le répertoire .ssh s'il n'existe pas
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        
        # Générer la clé SSH (Ed25519 recommandé)
        if [ -n "$GITHUB_EMAIL" ]; then
            ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f "$SSH_KEY_PATH" -N "" <<< "y" 2>/dev/null
        else
            ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" <<< "y" 2>/dev/null
        fi
        
        if [ $? -ne 0 ] || [ ! -f "$SSH_PUB_KEY_PATH" ]; then
            log_error "Échec de la génération de la clé SSH"
            return 1
        fi
        
        log_success "Clé SSH générée: $SSH_PUB_KEY_PATH"
        
        # Afficher la clé publique
        echo ""
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "Clé publique SSH générée:"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$SSH_PUB_KEY_PATH"
        echo ""
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Demander si l'utilisateur veut ajouter automatiquement la clé à GitHub
        echo ""
        read -p "Voulez-vous ajouter automatiquement cette clé à votre compte GitHub? (O/n): " ADD_TO_GITHUB
        
        if [[ "$ADD_TO_GITHUB" =~ ^[Nn]$ ]]; then
            log_info "Ajoutez manuellement la clé à votre compte GitHub:"
            log_info "1. Allez sur https://github.com/settings/keys"
            log_info "2. Cliquez sur 'New SSH key'"
            log_info "3. Collez le contenu de la clé ci-dessus"
            echo ""
            read -p "Appuyez sur Entrée après avoir ajouté la clé à GitHub..."
        else
            # Demander le token GitHub pour l'API
            echo ""
            log_info "Pour ajouter automatiquement la clé, vous avez besoin d'un token GitHub."
            log_info "Créez un token avec la permission 'admin:public_key' sur:"
            log_info "https://github.com/settings/tokens"
            echo ""
            read -p "Entrez votre token GitHub (ou appuyez sur Entrée pour ajouter manuellement): " GITHUB_TOKEN
            
            if [ -n "$GITHUB_TOKEN" ]; then
                # Lire la clé publique
                SSH_PUB_KEY=$(cat "$SSH_PUB_KEY_PATH")
                KEY_TITLE="UbuntuConfig-$(hostname)-$(date +%Y%m%d)"
                
                # Ajouter la clé via l'API GitHub
                log_info "Ajout de la clé SSH à votre compte GitHub..."
                
                API_RESPONSE=$(curl -s -X POST \
                    -H "Authorization: token $GITHUB_TOKEN" \
                    -H "Accept: application/vnd.github.v3+json" \
                    https://api.github.com/user/keys \
                    -d "{\"title\":\"$KEY_TITLE\",\"key\":\"$SSH_PUB_KEY\"}")
                
                if echo "$API_RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
                    KEY_ID=$(echo "$API_RESPONSE" | jq -r '.id')
                    log_success "Clé SSH ajoutée avec succès à votre compte GitHub (ID: $KEY_ID)"
                else
                    ERROR_MSG=$(echo "$API_RESPONSE" | jq -r '.message // "Erreur inconnue"' 2>/dev/null || echo "Erreur lors de l'ajout de la clé")
                    log_error "Échec de l'ajout automatique: $ERROR_MSG"
                    log_info "Ajoutez manuellement la clé à votre compte GitHub:"
                    log_info "1. Allez sur https://github.com/settings/keys"
                    log_info "2. Cliquez sur 'New SSH key'"
                    log_info "3. Collez le contenu de la clé ci-dessus"
                    echo ""
                    read -p "Appuyez sur Entrée après avoir ajouté la clé à GitHub..."
                fi
            else
                log_info "Ajoutez manuellement la clé à votre compte GitHub:"
                log_info "1. Allez sur https://github.com/settings/keys"
                log_info "2. Cliquez sur 'New SSH key'"
                log_info "3. Collez le contenu de la clé ci-dessus"
                echo ""
                read -p "Appuyez sur Entrée après avoir ajouté la clé à GitHub..."
            fi
        fi
        
        # Configurer SSH pour utiliser cette clé pour GitHub
        log_info "Configuration de SSH pour GitHub..."
        
        SSH_CONFIG="$HOME/.ssh/config"
        mkdir -p "$HOME/.ssh"
        
        # Vérifier si la configuration GitHub existe déjà
        if [ -f "$SSH_CONFIG" ] && grep -q "Host github.com" "$SSH_CONFIG"; then
            log_info "Configuration SSH GitHub existante trouvée"
        else
            # Ajouter la configuration GitHub
            {
                echo ""
                echo "Host github.com"
                echo "    HostName github.com"
                echo "    User git"
                echo "    IdentityFile $SSH_KEY_PATH"
                echo "    IdentitiesOnly yes"
            } >> "$SSH_CONFIG"
            chmod 600 "$SSH_CONFIG"
            log_success "Configuration SSH ajoutée pour GitHub"
        fi
        
        # Tester la connexion SSH
        log_info "Test de la connexion SSH à GitHub..."
        SSH_TEST_OUTPUT=$(ssh -T git@github.com -o StrictHostKeyChecking=no -o ConnectTimeout=5 2>&1)
        SSH_TEST_EXIT=$?
        
        if [ $SSH_TEST_EXIT -eq 1 ] && echo "$SSH_TEST_OUTPUT" | grep -qiE "(successfully authenticated|you've successfully authenticated)"; then
            log_success "Connexion SSH à GitHub réussie!"
        elif [ $SSH_TEST_EXIT -eq 255 ]; then
            log_warning "Impossible de se connecter à GitHub via SSH (timeout ou erreur de connexion)"
            log_info "Assurez-vous que la clé a été ajoutée à votre compte GitHub"
            log_info "Vous pouvez tester manuellement avec: ssh -T git@github.com"
        else
            log_info "Connexion SSH testée (code de sortie: $SSH_TEST_EXIT)"
            log_info "Vous pouvez tester manuellement avec: ssh -T git@github.com"
        fi
        
        echo ""
    }
    
    # Générer et configurer la clé SSH
    setup_ssh_key
    
    log_info "Récupération de la liste des dépôts pour $GITHUB_USERNAME..."
    
    # Récupérer la liste des dépôts via l'API GitHub (gérer la pagination)
    REPOS_JSON="[]"
    PAGE=1
    PER_PAGE=100
    
    while true; do
        PAGE_JSON=$(curl -s "https://api.github.com/users/$GITHUB_USERNAME/repos?per_page=$PER_PAGE&page=$PAGE" 2>/dev/null)
        
        if [ $? -ne 0 ] || [ -z "$PAGE_JSON" ]; then
            log_error "Impossible de récupérer les dépôts pour $GITHUB_USERNAME"
            return 1
        fi
        
        # Vérifier si l'utilisateur existe ou erreur
        if echo "$PAGE_JSON" | jq -e '.message' > /dev/null 2>&1; then
            ERROR_MSG=$(echo "$PAGE_JSON" | jq -r '.message // "Erreur inconnue"')
            log_error "Erreur GitHub: $ERROR_MSG"
            return 1
        fi
        
        # Vérifier si la page est vide
        PAGE_COUNT=$(echo "$PAGE_JSON" | jq '. | length')
        if [ "$PAGE_COUNT" -eq 0 ]; then
            break
        fi
        
        # Fusionner avec les dépôts précédents
        REPOS_JSON=$(echo "$REPOS_JSON" | jq ". + $PAGE_JSON")
        
        # Si on a moins de dépôts que la page maximale, on a fini
        if [ "$PAGE_COUNT" -lt "$PER_PAGE" ]; then
            break
        fi
        
        PAGE=$((PAGE + 1))
    done
    
    # Compter le nombre de dépôts
    REPO_COUNT=$(echo "$REPOS_JSON" | jq '. | length')
    
    if [ "$REPO_COUNT" -eq 0 ]; then
        log_warning "Aucun dépôt trouvé pour $GITHUB_USERNAME"
        return 0
    fi
    
    log_info "Nombre de dépôts trouvés: $REPO_COUNT"
    echo ""
    
    # Compteurs (utiliser des fichiers temporaires pour persister dans la boucle)
    TEMP_COUNTERS=$(mktemp)
    echo "0|0|0" > "$TEMP_COUNTERS"
    
    # Cloner chaque dépôt
    CLONE_TOTAL=0
    while IFS='|' read -r repo_name clone_url_https is_private ssh_url; do
        CLONE_TOTAL=$((CLONE_TOTAL + 1))
        
        REPO_DIR="$CLONE_DIR/$repo_name"
        
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "[$CLONE_TOTAL/$REPO_COUNT] Dépôt: $repo_name"
        if [ "$is_private" = "true" ]; then
            log_info "Type: Privé"
        fi
        
        # Choisir l'URL de clonage (préférer SSH pour les dépôts privés si disponible)
        if [ "$is_private" = "true" ] && [ -n "$ssh_url" ] && [ "$ssh_url" != "null" ]; then
            CLONE_URL="$ssh_url"
            log_info "Utilisation de SSH pour le dépôt privé"
        else
            CLONE_URL="$clone_url_https"
        fi
        
        # Vérifier si le dépôt existe déjà
        if [ -d "$REPO_DIR" ]; then
            log_warning "Le dépôt $repo_name existe déjà dans $REPO_DIR"
            read -p "Voulez-vous le mettre à jour? (o/N): " UPDATE_REPO
            if [[ "$UPDATE_REPO" =~ ^[Oo]$ ]]; then
                log_info "Mise à jour du dépôt $repo_name..."
                cd "$REPO_DIR"
                if git pull 2>/dev/null; then
                    log_success "Dépôt $repo_name mis à jour"
                    IFS='|' read -r success skipped failed < "$TEMP_COUNTERS"
                    echo "$((success + 1))|$skipped|$failed" > "$TEMP_COUNTERS"
                else
                    log_error "Échec de la mise à jour de $repo_name"
                    IFS='|' read -r success skipped failed < "$TEMP_COUNTERS"
                    echo "$success|$skipped|$((failed + 1))" > "$TEMP_COUNTERS"
                fi
            else
                log_info "Dépôt $repo_name ignoré"
                IFS='|' read -r success skipped failed < "$TEMP_COUNTERS"
                echo "$success|$((skipped + 1))|$failed" > "$TEMP_COUNTERS"
            fi
        else
            # Cloner le dépôt
            log_info "Clonage depuis: $CLONE_URL"
            
            if git clone "$CLONE_URL" "$REPO_DIR" 2>/dev/null; then
                log_success "Dépôt $repo_name cloné avec succès"
                IFS='|' read -r success skipped failed < "$TEMP_COUNTERS"
                echo "$((success + 1))|$skipped|$failed" > "$TEMP_COUNTERS"
            else
                log_error "Échec du clonage de $repo_name"
                if [ "$is_private" = "true" ]; then
                    log_warning "Pour les dépôts privés, assurez-vous d'avoir configuré SSH ou les credentials Git"
                fi
                IFS='|' read -r success skipped failed < "$TEMP_COUNTERS"
                echo "$success|$skipped|$((failed + 1))" > "$TEMP_COUNTERS"
            fi
        fi
        echo ""
    done < <(echo "$REPOS_JSON" | jq -r '.[] | "\(.name)|\(.clone_url)|\(.private)|\(.ssh_url)"')
    
    # Lire les compteurs finaux
    IFS='|' read -r CLONE_SUCCESS CLONE_SKIPPED CLONE_FAILED < "$TEMP_COUNTERS"
    rm -f "$TEMP_COUNTERS"
    
    # Afficher le résumé
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Résumé du clonage GitHub:"
    log_info "  Utilisateur: $GITHUB_USERNAME"
    log_info "  Répertoire: $CLONE_DIR"
    log_info "  Total: $REPO_COUNT"
    log_success "  Clonés/Mis à jour: $CLONE_SUCCESS"
    if [ "$CLONE_SKIPPED" -gt 0 ]; then
        log_warning "  Ignorés: $CLONE_SKIPPED"
    fi
    if [ "$CLONE_FAILED" -gt 0 ]; then
        log_error "  Échoués: $CLONE_FAILED"
    fi
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Proposer de cloner les dépôts GitHub
echo ""
read -p "Voulez-vous cloner des dépôts GitHub? (o/N): " CLONE_GITHUB

if [[ "$CLONE_GITHUB" =~ ^[Oo]$ ]]; then
    clone_github_repos
fi
