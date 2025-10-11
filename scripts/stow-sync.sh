#!/bin/bash

# Script para sincronizar dotfiles usando GNU Stow
# Autor: v1cferr
# Data: $(date +%Y-%m-%d)

set -e  # Para em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório base dos dotfiles
DOTFILES_DIR="$HOME/dotfiles"

# Função para log
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verifica se estamos no diretório correto
check_directory() {
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        error "Diretório $DOTFILES_DIR não encontrado!"
        exit 1
    fi
    
    cd "$DOTFILES_DIR"
    log "Trabalhando no diretório: $(pwd)"
}

# Lista todos os pacotes disponíveis
list_packages() {
    log "Pacotes disponíveis para stow:"
    for dir in */; do
        if [[ -d "$dir" && "$dir" != "scripts/" && "$dir" != "wallpapers/" ]]; then
            echo "  - ${dir%/}"
        fi
    done
}

# Aplica stow para um pacote específico
stow_package() {
    local package="$1"
    
    if [[ ! -d "$package" ]]; then
        error "Pacote '$package' não encontrado!"
        return 1
    fi
    
    log "Aplicando stow para o pacote: $package"
    
    # Verifica se já existe link
    if stow -n "$package" 2>/dev/null; then
        stow "$package"
        success "Pacote '$package' aplicado com sucesso!"
    else
        warning "Possível conflito detectado para '$package'"
        echo "Deseja forçar a aplicação? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            stow --adopt "$package"
            success "Pacote '$package' aplicado com --adopt!"
        else
            error "Aplicação cancelada para '$package'"
        fi
    fi
}

# Remove stow para um pacote
unstow_package() {
    local package="$1"
    
    log "Removendo stow para o pacote: $package"
    stow -D "$package"
    success "Pacote '$package' removido com sucesso!"
}

# Aplica stow para todos os pacotes
stow_all() {
    log "Aplicando stow para todos os pacotes..."
    
    local packages=()
    for dir in */; do
        if [[ -d "$dir" && "$dir" != "scripts/" && "$dir" != "wallpapers/" ]]; then
            packages+=("${dir%/}")
        fi
    done
    
    for package in "${packages[@]}"; do
        stow_package "$package"
    done
    
    success "Todos os pacotes foram processados!"
}

# Reaplica todos os pacotes (útil após mudanças)
restow_all() {
    log "Reaplicando todos os pacotes..."
    
    local packages=()
    for dir in */; do
        if [[ -d "$dir" && "$dir" != "scripts/" && "$dir" != "wallpapers/" ]]; then
            packages+=("${dir%/}")
        fi
    done
    
    for package in "${packages[@]}"; do
        log "Reaplicando: $package"
        stow -R "$package"
    done
    
    success "Todos os pacotes foram reaplicados!"
}

# Mostra status dos links
show_status() {
    log "Status dos links simbólicos:"
    
    # Verifica alguns arquivos importantes
    local files=(
        "$HOME/.zshrc"
        "$HOME/.config/hypr"
        "$HOME/.config/waybar"
        "$HOME/.config/rofi"
    )
    
    for file in "${files[@]}"; do
        if [[ -L "$file" ]]; then
            local target=$(readlink -f "$file")
            if [[ "$target" == *"$DOTFILES_DIR"* ]]; then
                echo -e "  ${GREEN}✓${NC} $file -> $target"
            else
                echo -e "  ${YELLOW}!${NC} $file -> $target (não gerenciado pelo dotfiles)"
            fi
        elif [[ -e "$file" ]]; then
            echo -e "  ${RED}✗${NC} $file (arquivo real, não é link)"
        else
            echo -e "  ${YELLOW}-${NC} $file (não existe)"
        fi
    done
}

# Função de ajuda
show_help() {
    cat << EOF
Uso: $0 [COMANDO] [PACOTE]

Comandos:
  list                  Lista todos os pacotes disponíveis
  stow <pacote>         Aplica stow para um pacote específico
  unstow <pacote>       Remove stow para um pacote específico
  stow-all             Aplica stow para todos os pacotes
  restow-all           Reaplica todos os pacotes
  status               Mostra status dos links simbólicos
  help                 Mostra esta ajuda

Exemplos:
  $0 list              # Lista pacotes disponíveis
  $0 stow zsh          # Aplica stow apenas para zsh
  $0 stow-all          # Aplica stow para tudo
  $0 status            # Verifica status dos links

EOF
}

# Função principal
main() {
    check_directory
    
    case "${1:-help}" in
        "list")
            list_packages
            ;;
        "stow")
            if [[ -z "$2" ]]; then
                error "Especifique um pacote para aplicar stow"
                show_help
                exit 1
            fi
            stow_package "$2"
            ;;
        "unstow")
            if [[ -z "$2" ]]; then
                error "Especifique um pacote para remover stow"
                show_help
                exit 1
            fi
            unstow_package "$2"
            ;;
        "stow-all")
            stow_all
            ;;
        "restow-all")
            restow_all
            ;;
        "status")
            show_status
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            error "Comando desconhecido: $1"
            show_help
            exit 1
            ;;
    esac
}

# Executa função principal com todos os argumentos
main "$@"