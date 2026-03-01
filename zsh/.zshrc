# ~/.zshrc

# --- 1. Variáveis de Ambiente ---
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export TERMINAL="kitty"
export EDITOR='nano'
export LANG=en_US.UTF-8

# --- 2. Histórico do Zsh (Configuração manual necessária sem o OMZ) ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY

# --- 3. Plugins Nativos do Arch (Performance Máxima) ---
# Syntax Highlighting
if [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Autosuggestions
if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    # Configuração de cor para sugestão (cinza claro para não confundir)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=60'
fi

# --- 4. Keybindings Básicos (Para Home, End, Delete funcionarem) ---
bindkey "^[[3~" delete-char
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# --- 5. UI/UX ---
export GTK_THEME=Tokyonight-Dark
export QT_QPA_PLATFORM=wayland
export LIBVIRT_DEFAULT_URI='qemu:///system'

# --- 6. Aliases ---
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias screenshot="flameshot gui"
alias stow-sync="~/dotfiles/scripts/stow-sync.sh"
alias ll='ls -l'
alias la='ls -la'
# Alias útil para atualizar tudo (já que configuramos o pacman bonito)
alias update='sudo pacman -Syu'
# Alias para iniciar Hyprland com configurações apropriadas
alias hyprland='start-hyprland'

# --- 7. Funções Úteis (Substituindo plugins do OMZ) ---

# Função "sudo" rápida: Aperte ESC duas vezes para adicionar sudo no começo da linha
sudo-command-line() {
    [[ -z $BUFFER ]] && zle up-history
    if [[ $BUFFER == sudo\ * ]]; then
        LBUFFER="${LBUFFER#sudo }"
    else
        LBUFFER="sudo $LBUFFER"
    fi
}
zle -N sudo-command-line
bindkey "\e\e" sudo-command-line

# --- 8. Inicialização de Ambientes e Ferramentas ---

# Starship (Prompt)
eval "$(starship init zsh)"

# .NET
export PATH="$HOME/.dotnet/tools:$PATH"

# Dart/Flutter Completion
[[ -f /home/v1cferr/.dart-cli-completion/zsh-config.zsh ]] && . /home/v1cferr/.dart-cli-completion/zsh-config.zsh || true

# pnpm
export PNPM_HOME="/home/v1cferr/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# Lazy load conda (Opcional: se não usar, pode remover este bloco inteiro)
conda() {
    unset -f conda
    __conda_setup="$('/home/v1cferr/miniconda/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "/home/v1cferr/miniconda/etc/profile.d/conda.sh" ]; then
            . "/home/v1cferr/miniconda/etc/profile.d/conda.sh"
        else
            export PATH="/home/v1cferr/miniconda/bin:$PATH"
        fi
    fi
    unset __conda_setup
    conda "$@"
}

# --- 9. Startup ---

# Mostrar informações do sistema ao iniciar
if [[ $- == *i* ]]; then
  fastfetch
fi