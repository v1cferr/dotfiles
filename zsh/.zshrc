# ~/.zshrc

# --- 1. Variáveis de Ambiente ---
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export TERMINAL="kitty"
export EDITOR='nano'
export LANG=en_US.UTF-8

# Desativa histórico do fzf
export FZF_CTRL_R_COMMAND=

# --- 2. Histórico do Zsh (Configuração manual necessária sem o OMZ) ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
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
alias grep='grep --color=auto'
alias screenshot="flameshot gui"
alias scfull='flameshot full -c'
alias sc1='flameshot screen --number 1 -c'
alias sc2='flameshot screen --number 0 -c'
alias stow-sync="~/dotfiles/scripts/stow-sync.sh"
alias hyprland='start-hyprland'
alias nrd='npm run dev'
alias vpn-status='vpn status'
alias vpn-ufscar='$HOME/dotfiles/scripts/ufscar-vpn.sh'
alias vpn-fai='$HOME/dotfiles/scripts/fai-ufscar-vpn.sh'
# vpn-off agora é um comando no PATH (~/.local/bin/vpn-off) — sem alias.

# Se o terminal for kitty, força o SSH a se identificar como xterm-256color
alias ssh="TERM=xterm-256color ssh"

# Busca apenas na HOME (Super rápido)
alias fhome='cd $(dirname $(fd -t f --exclude node_modules --exclude .cache . ~ | fzf))'

# Busca no PC inteiro (Raiz)
alias froot='cd $(dirname $(fd -t f --exclude node_modules --exclude .cache . / 2>/dev/null | fzf))'

# Manutenção
alias update='sudo pacman -Syu && yay -Syu'
alias clean='sudo pacman -Rns $(pacman -Qtdq)'

# Eza (Melhor que ls) - Instale com: sudo pacman -S eza
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -l --icons --group-directories-first'
    alias la='eza -la --icons --group-directories-first'
else
    alias ls='ls --color=auto'
    alias ll='ls -l'
    alias la='ls -la'
fi

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

# Evals de inicialização (atuin, starship, zoxide)
eval "$(atuin init zsh)"
eval "$(starship init zsh)"

# Zoxide (Substituto do cd) - Instale com: sudo pacman -S zoxide
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
    alias cd="z"
fi

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

# --- 10. Bindkeys ---

bindkey '^[[A' up-line-or-history
bindkey '^[[B' down-line-or-history

fzf-history-widget() {
  BUFFER=$(history -n 1 | tac | fzf --tac --height 40% --reverse)
  CURSOR=$#BUFFER
  zle reset-prompt
}

zle -N fzf-history-widget
bindkey '^R' atuin-search
bindkey '^[r' fzf-history-widget

# opencode
export PATH=/home/v1cferr/.opencode/bin:$PATH

# ==============================
# YOUTUBE / MPV
# ==============================

YOUTUBE_PLAYLIST="https://www.youtube.com/playlist?list=PLFxBBkriBXUVCKyD3LKYZRAACJX67A-ng"

# TUI do YouTube
alias yttui='yt'

# Tocar minha playlist apenas com áudio
alias ytmix='mpv --no-video --force-window=no --save-position-on-quit=no --ytdl-format=bestaudio --shuffle "$YOUTUBE_PLAYLIST"'

# Tocar minha playlist com vídeo até 1080p
alias ytvideo='mpv --profile=fast --hwdec=auto-safe --cache=yes --ytdl-raw-options="extractor-retries=3,fragment-retries=3,retries=3" --ytdl-format="bestvideo[vcodec!=av01][height<=1080]+bestaudio/bestvideo[height<=1080]+bestaudio/best[height<=1080]" --shuffle "$YOUTUBE_PLAYLIST"'

# Tocar qualquer link do YouTube apenas com áudio
alias ytaudio='mpv --no-video --force-window=no --ytdl-format=bestaudio'

# Assistir qualquer link do YouTube com vídeo até 1080p
alias ytwatch='mpv --profile=fast --hwdec=auto-safe --cache=yes --ytdl-raw-options="extractor-retries=3,fragment-retries=3,retries=3" --ytdl-format="bestvideo[vcodec!=av01][height<=1080]+bestaudio/bestvideo[height<=1080]+bestaudio/best[height<=1080]"'

# ==============================
# CLAUDE CODE / MÚLTIPLAS CONTAS
# ==============================
# Cada conta usa um CLAUDE_CONFIG_DIR isolado e DEDICADO (login, sessões, MCP, settings).
# Obs: NÃO reaproveitar ~/.claude aqui — o config padrão fica em ~/.claude.json (home),
# então apontar CLAUDE_CONFIG_DIR pra ~/.claude criaria um 2º arquivo (~/.claude/.claude.json)
# divergente. Por isso cada conta tem pasta própria; ~/.claude/~/.claude.json fica como padrão.
#   ~/.claude-fai      -> FAI / nonprofit (victor.ferreira@fai.ufscar.br)
#   ~/.claude-pessoal  -> pessoal         (dragons10021@outlook.com)
export CLAUDE_FAI_DIR="$HOME/.claude-fai"
export CLAUDE_PESSOAL_DIR="$HOME/.claude-pessoal"

# Aliases diretos (aceitam argumentos extras normalmente)
alias claude-fai='CLAUDE_CONFIG_DIR="$CLAUDE_FAI_DIR" claude'
alias claude-pessoal='CLAUDE_CONFIG_DIR="$CLAUDE_PESSOAL_DIR" claude'

# Monitor de uso ao vivo (tokens/custo do bloco atual), atualiza a cada 1s
alias claude-usage='watch -n 1 -c ccusage blocks --active --color'
# Uso detalhado por sessão (tabela: tokens/custo de cada sessão)
alias claude-usage-sessions='ccusage session --color'

# Seletor interativo: escolhe a conta na hora com fzf
#   uso: claude-pick            (abre menu e inicia)
#        claude-pick <args...>  (passa argumentos pro claude)
claude-pick() {
    local choice
    choice=$(printf '%s\n%s' \
        'FAI      (victor.ferreira@fai.ufscar.br)' \
        'Pessoal  (dragons10021@outlook.com)' \
        | fzf --prompt='Conta Claude > ' --height=25% --reverse) || return
    case "$choice" in
        FAI*)     CLAUDE_CONFIG_DIR="$CLAUDE_FAI_DIR" claude "$@" ;;
        Pessoal*) CLAUDE_CONFIG_DIR="$CLAUDE_PESSOAL_DIR" claude "$@" ;;
    esac
}