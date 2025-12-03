# ~/.zshrc

# --- 1. Variáveis de Ambiente Básicas ---
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export ZSH="$HOME/.oh-my-zsh"
export TERMINAL="kitty" # Ou seu terminal preferido
export EDITOR='nano'
export LANG=en_US.UTF-8

# --- 2. Oh My Zsh (Apenas libs básicas, sem tema) ---
# Deixamos vazio para o Starship assumir o controle depois
ZSH_THEME=""

# Plugins básicos do OMZ (apenas git e sudo, os pesados carregamos via pacman abaixo)
plugins=(git sudo)

# Carrega o OMZ
source $ZSH/oh-my-zsh.sh

# --- 3. Plugins de Performance do Arch (Mais rápidos que via OMZ) ---
# Certifique-se de ter instalado: sudo pacman -S zsh-syntax-highlighting zsh-autosuggestions
if [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# --- 4. Configurações de UI/UX ---
# Correção de título e cores
DISABLE_AUTO_TITLE="true"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"

# Tema GTK e Wayland
export GTK_THEME=Tokyonight-Dark
export QT_QPA_PLATFORM=wayland
export LIBVIRT_DEFAULT_URI='qemu:///system'

# --- 5. Aliases ---
alias screenshot="flameshot gui"
alias stow-sync="~/dotfiles/scripts/stow-sync.sh"
# Adicione mais aliases aqui...

# --- 6. Inicialização de Ambientes (Python, Java, etc) ---

# Pyenv
# export PYENV_ROOT="$HOME/.pyenv"
# [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
# if command -v pyenv 1>/dev/null 2>&1; then
#   eval "$(pyenv init -)"
# fi

# UV
# if [ -f "$HOME/.local/bin/env" ]; then
#     source "$HOME/.local/bin/env"
# fi

# Conda (Bloco Otimizado)
# if [ -f "/home/v1cferr/miniconda3/etc/profile.d/conda.sh" ]; then
#     . "/home/v1cferr/miniconda3/etc/profile.d/conda.sh"
# else
#     export PATH="/home/v1cferr/miniconda3/bin:$PATH"
# fi

# SDKMan
# export SDKMAN_DIR="$HOME/.sdkman"
# [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Dart/Flutter
# [[ -f /home/v1cferr/.dart-cli-completion/zsh-config.zsh ]] && . /home/v1cferr/.dart-cli-completion/zsh-config.zsh || true

# --- 7. Starship (O novo Prompt) ---
# Inicializa o starship no final para garantir que ele sobrescreva qualquer prompt anterior
eval "$(starship init zsh)"