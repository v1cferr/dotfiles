# CONFIG do starship (~/.config/starship.toml), declarado. Prompt cross-shell rápido
# (Rust) — aqui roda no zsh (home/zsh.nix); a integração é injetada automaticamente
# (enableZshIntegration, ligado por padrão → `eval "$(starship init zsh)"`). O pacote
# vem deste módulo do home-manager. Ícones vêm da JetBrains Mono Nerd Font (system/).
{ ... }:

{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true; # linha em branco antes de cada prompt (respiro visual)

      # Prompt em 2 linhas: infos em cima, símbolo de digitação embaixo.
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";

      # Símbolo do prompt: ❯ verde quando o último comando deu certo, vermelho se falhou.
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      # Caminho atual: trunca em 3 níveis, negrito azul.
      directory = {
        truncation_length = 3;
        truncate_to_repo = true; # dentro de um repo, mostra a partir da raiz dele
        style = "bold blue";
      };

      # Git: branch + estado (arquivos modificados/staged/etc.).
      git_branch.style = "bold purple";
      git_status.style = "bold yellow";

      # Mostra quanto tempo o comando levou quando passa de 2s (útil pra builds/rebuilds).
      cmd_duration = {
        min_time = 2000;
        format = "[took $duration]($style) ";
        style = "italic yellow";
      };
    };
  };
}
