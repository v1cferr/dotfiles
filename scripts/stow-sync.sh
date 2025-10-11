#!/bin/bash

# Script para sincronizar dotfiles usando GNU Stow
# Autor: v1cferr
# Data: $(date +%Y-%m-%d)
#
# DESCRIÇÃO:
#   Este script automatiza o gerenciamento de dotfiles usando GNU Stow.
#   Permite aplicar, remover e gerenciar links simbólicos de forma centralizada.
#
# PRÉ-REQUISITOS:
#   - GNU Stow instalado (pacman -S stow / apt install stow)
#   - Estrutura de dotfiles organizada em ~/dotfiles/
#   - Cada pacote deve seguir a estrutura: pacote/.config/app/ ou pacote/.arquivo
#
# ESTRUTURA ESPERADA:
#   ~/dotfiles/
#   ├── zsh/
#   │   └── .zshrc          # -> ~/.zshrc
#   ├── hypr/
#   │   └── .config/
#   │       └── hypr/       # -> ~/.config/hypr/
#   └── waybar/
#       └── .config/
#           └── waybar/     # -> ~/.config/waybar/
#
# ALIAS RECOMENDADO (adicionar ao .zshrc):
#   alias stow-sync="~/dotfiles/scripts/stow-sync.sh"
#
# EXEMPLOS DE USO:
#   stow-sync list          # Lista pacotes disponíveis
#   stow-sync status        # Mostra status dos links
#   stow-sync stow zsh      # Aplica apenas o pacote zsh
#   stow-sync stow-all      # Aplica todos os pacotes
#   stow-sync restow-all    # Reaplica todos os pacotes
#
# FLUXO DE TRABALHO RECOMENDADO:
#   1. Editar arquivo: vim ~/.zshrc
#   2. Verificar mudanças: stow-sync status
#   3. Commit: git add -A && git commit -m "update config"
#   4. Push: git push
#
# SINCRONIZAÇÃO EM NOVA MÁQUINA:
#   git clone <repo> ~/dotfiles
#   cd ~/dotfiles
#   stow-sync stow-all
#
# TROUBLESHOOTING:
#   - Conflitos: Use stow-sync stow --adopt <pacote>
#   - Links quebrados: stow-sync restow-all
#   - Estrutura incorreta: Verificar se pacote/.config/app existe

set -e  # Para em caso de erro

# ============================================================================
# CONFIGURAÇÕES E VARIÁVEIS
# ============================================================================

# Cores para output colorido no terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório base dos dotfiles (pode ser alterado se necessário)
DOTFILES_DIR="$HOME/dotfiles"

# ============================================================================
# FUNÇÕES DE LOGGING
# ============================================================================

# Função para mensagens informativas
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Função para mensagens de sucesso
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Função para mensagens de aviso
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Função para mensagens de erro
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# FUNÇÕES PRINCIPAIS
# ============================================================================

# Verifica se o diretório de dotfiles existe e navega para ele
# Esta função garante que o script sempre execute do diretório correto
check_directory() {
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        error "Diretório $DOTFILES_DIR não encontrado!"
        error "Certifique-se de que seus dotfiles estão em $DOTFILES_DIR"
        exit 1
    fi
    
    cd "$DOTFILES_DIR"
    log "Trabalhando no diretório: $(pwd)"
}

# Lista todos os pacotes disponíveis para aplicar com stow
# Exclui diretórios que não são pacotes de configuração (scripts, wallpapers)
list_packages() {
    log "Pacotes disponíveis para stow:"
    local count=0
    for dir in */; do
        if [[ -d "$dir" && "$dir" != "scripts/" && "$dir" != "wallpapers/" ]]; then
            echo "  - ${dir%/}"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        warning "Nenhum pacote encontrado!"
        log "Certifique-se de que existe pelo menos um diretório com configurações."
    else
        log "Total: $count pacote(s) encontrado(s)"
    fi
}

# Aplica stow para um pacote específico
# Cria links simbólicos do pacote para os locais apropriados na HOME
# Exemplo: stow zsh -> cria link ~/.zshrc -> ~/dotfiles/zsh/.zshrc
stow_package() {
    local package="$1"
    
    if [[ ! -d "$package" ]]; then
        error "Pacote '$package' não encontrado!"
        log "Pacotes disponíveis: $(ls -d */ 2>/dev/null | grep -v 'scripts/\|wallpapers/' | tr '\n' ' ')"
        return 1
    fi
    
    log "Aplicando stow para o pacote: $package"
    
    # Testa a aplicação primeiro (dry-run)
    if stow -n "$package" 2>/dev/null; then
        stow "$package"
        success "Pacote '$package' aplicado com sucesso!"
    else
        warning "Possível conflito detectado para '$package'"
        warning "Isso geralmente significa que já existe um arquivo no destino."
        echo "Opções:"
        echo "  y) Usar --adopt (move arquivo existente para o pacote)"
        echo "  N) Cancelar aplicação"
        echo -n "Deseja usar --adopt? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            stow --adopt "$package"
            success "Pacote '$package' aplicado com --adopt!"
            warning "IMPORTANTE: Verifique se o arquivo movido está correto!"
        else
            error "Aplicação cancelada para '$package'"
            log "Dica: Remova ou faça backup do arquivo conflitante manualmente"
        fi
    fi
}

# Remove os links simbólicos de um pacote específico
# Os arquivos originais no repositório permanecem intactos
unstow_package() {
    local package="$1"
    
    if [[ ! -d "$package" ]]; then
        error "Pacote '$package' não encontrado!"
        return 1
    fi
    
    log "Removendo links simbólicos do pacote: $package"
    stow -D "$package"
    success "Links do pacote '$package' removidos com sucesso!"
    log "Os arquivos em ~/dotfiles/$package/ permanecem intactos"
}

# Aplica stow para todos os pacotes encontrados
# Útil para configuração inicial ou após clonar o repositório
stow_all() {
    log "Aplicando stow para todos os pacotes..."
    
    local packages=()
    for dir in */; do
        if [[ -d "$dir" && "$dir" != "scripts/" && "$dir" != "wallpapers/" ]]; then
            packages+=("${dir%/}")
        fi
    done
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        warning "Nenhum pacote encontrado para aplicar!"
        return 1
    fi
    
    log "Encontrados ${#packages[@]} pacote(s): ${packages[*]}"
    
    local failed=0
    for package in "${packages[@]}"; do
        if ! stow_package "$package"; then
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        success "Todos os ${#packages[@]} pacotes foram aplicados com sucesso!"
    else
        warning "$failed pacote(s) falharam na aplicação"
        log "Execute 'stow-sync status' para verificar o estado atual"
    fi
}

# Reaplica todos os pacotes (remove e aplica novamente)
# Útil após mudanças na estrutura dos dotfiles ou resolução de conflitos
restow_all() {
    log "Reaplicando todos os pacotes..."
    log "Isso remove e recria todos os links simbólicos"
    
    local packages=()
    for dir in */; do
        if [[ -d "$dir" && "$dir" != "scripts/" && "$dir" != "wallpapers/" ]]; then
            packages+=("${dir%/}")
        fi
    done
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        warning "Nenhum pacote encontrado para reaplicar!"
        return 1
    fi
    
    local failed=0
    for package in "${packages[@]}"; do
        log "Reaplicando: $package"
        if stow -R "$package" 2>/dev/null; then
            success "✓ $package reaplicado"
        else
            error "✗ Falha ao reaplicar $package"
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        success "Todos os ${#packages[@]} pacotes foram reaplicados com sucesso!"
    else
        warning "$failed pacote(s) falharam na reaplicação"
    fi
}

# Mostra o status dos links simbólicos principais
# Verifica se os arquivos estão corretamente linkados para o repositório dotfiles
show_status() {
    log "Status dos links simbólicos dos dotfiles:"
    
    # Lista arquivos/diretórios importantes para verificar
    local files=(
        "$HOME/.zshrc"
        "$HOME/.config/hypr"
        "$HOME/.config/waybar"
        "$HOME/.config/rofi"
        "$HOME/.gitconfig"
        "$HOME/.config/swaync"
    )
    
    local managed=0
    local unmanaged=0
    local missing=0
    local broken=0
    
    for file in "${files[@]}"; do
        if [[ -L "$file" ]]; then
            local target=$(readlink -f "$file")
            if [[ "$target" == *"$DOTFILES_DIR"* ]]; then
                if [[ -e "$target" ]]; then
                    echo -e "  ${GREEN}✓${NC} $file -> $target"
                    ((managed++))
                else
                    echo -e "  ${RED}✗${NC} $file -> $target (link quebrado)"
                    ((broken++))
                fi
            else
                echo -e "  ${YELLOW}!${NC} $file -> $target (não gerenciado pelo dotfiles)"
                ((unmanaged++))
            fi
        elif [[ -e "$file" ]]; then
            echo -e "  ${RED}✗${NC} $file (arquivo real, não é link simbólico)"
            ((unmanaged++))
        else
            echo -e "  ${YELLOW}-${NC} $file (não existe)"
            ((missing++))
        fi
    done
    
    # Resumo do status
    echo
    log "Resumo:"
    echo "  - Gerenciados pelo dotfiles: $managed"
    echo "  - Não gerenciados: $unmanaged"  
    echo "  - Não existem: $missing"
    if [[ $broken -gt 0 ]]; then
        echo "  - Links quebrados: $broken"
        warning "Execute 'stow-sync restow-all' para corrigir links quebrados"
    fi
}

# Exibe a ajuda completa do script
show_help() {
    cat << EOF
╭─────────────────────────────────────────────────────────────────────────╮
│                        STOW-SYNC - Gerenciador de Dotfiles             │
│                                                                         │
│ Script para automatizar o gerenciamento de dotfiles usando GNU Stow    │
╰─────────────────────────────────────────────────────────────────────────╯

USO:
    $0 [COMANDO] [PACOTE]

COMANDOS PRINCIPAIS:
    list                  Lista todos os pacotes disponíveis
    status               Mostra status dos links simbólicos
    stow <pacote>        Aplica stow para um pacote específico
    unstow <pacote>      Remove stow para um pacote específico
    stow-all            Aplica stow para todos os pacotes
    restow-all          Reaplica todos os pacotes (útil após mudanças)
    help                Mostra esta ajuda

EXEMPLOS DE USO:
    $0 list             # Lista pacotes: zsh, hypr, waybar, etc.
    $0 status           # Verifica quais arquivos estão linkados
    $0 stow zsh         # Aplica apenas configurações do zsh
    $0 stow-all         # Configuração inicial - aplica tudo
    $0 restow-all       # Resolve conflitos - reaplica tudo
    $0 unstow waybar    # Remove links do waybar

FLUXO DE TRABALHO TÍPICO:
    1. Editar arquivo:        vim ~/.zshrc
    2. Verificar status:      $0 status
    3. Commit mudanças:       git add -A && git commit -m "update config"
    4. Push para repo:        git push

NOVA MÁQUINA:
    git clone <seu-repo> ~/dotfiles
    cd ~/dotfiles
    $0 stow-all

RESOLUÇÃO DE PROBLEMAS:
    - Conflitos de arquivo:   $0 stow --adopt <pacote>
    - Links quebrados:        $0 restow-all
    - Ver documentação:       cat ~/dotfiles/GUIA-STOW-COMPLETO.md

ESTRUTURA NECESSÁRIA:
    ~/dotfiles/pacote/.config/app/    -> ~/.config/app/
    ~/dotfiles/pacote/.arquivo        -> ~/.arquivo

EOF
}

# Mostra informações sobre o repositório de dotfiles
show_info() {
    log "Informações do repositório de dotfiles:"
    echo "  📁 Localização: $DOTFILES_DIR"
    
    if command -v git >/dev/null 2>&1 && [[ -d "$DOTFILES_DIR/.git" ]]; then
        local branch=$(git branch --show-current 2>/dev/null || echo "desconhecida")
        local remote=$(git remote get-url origin 2>/dev/null || echo "não configurado")
        local commits=$(git rev-list --count HEAD 2>/dev/null || echo "?")
        echo "  🌿 Branch atual: $branch"
        echo "  🔗 Remote: $remote"
        echo "  📊 Commits: $commits"
        
        # Verifica se há mudanças não commitadas
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            warning "  ⚠️  Há mudanças não commitadas!"
        else
            success "  ✓ Repositório limpo"
        fi
    else
        warning "  ⚠️  Não é um repositório Git ou Git não instalado"
    fi
    
    # Verifica se GNU Stow está instalado
    if command -v stow >/dev/null 2>&1; then
        local stow_version=$(stow --version 2>/dev/null | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "desconhecida")
        success "  ✓ GNU Stow instalado (versão: $stow_version)"
    else
        error "  ✗ GNU Stow não encontrado!"
        log "    Instale com: sudo pacman -S stow (Arch) ou sudo apt install stow (Ubuntu)"
    fi
}

# ============================================================================
# FUNÇÃO PRINCIPAL
# ============================================================================

# Função principal que processa os argumentos e executa o comando apropriado
main() {
    # Exibe banner apenas para comandos que mostram informações
    case "${1:-help}" in
        "help"|"--help"|"-h"|"info")
            echo "🔧 STOW-SYNC v1.0 - Gerenciador de Dotfiles"
            echo "════════════════════════════════════════════"
            ;;
    esac
    
    check_directory
    
    case "${1:-help}" in
        "list")
            list_packages
            ;;
        "stow")
            if [[ -z "$2" ]]; then
                error "Especifique um pacote para aplicar stow"
                echo
                log "Pacotes disponíveis:"
                list_packages
                exit 1
            fi
            stow_package "$2"
            ;;
        "unstow")
            if [[ -z "$2" ]]; then
                error "Especifique um pacote para remover stow"
                echo
                log "Pacotes disponíveis:"
                list_packages
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
        "info")
            show_info
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            error "Comando desconhecido: '$1'"
            echo
            log "Comandos disponíveis: list, status, stow, unstow, stow-all, restow-all, info, help"
            log "Use '$0 help' para ver a ajuda completa"
            exit 1
            ;;
    esac
}

# ============================================================================
# EXECUÇÃO DO SCRIPT
# ============================================================================

# Executa a função principal passando todos os argumentos da linha de comando
# Exemplo: ./stow-sync.sh list -> main "list"
# Exemplo: ./stow-sync.sh stow zsh -> main "stow" "zsh"
main "$@"