# CLIs de usuário SEM config declarativa própria — agrupados numa lista (idiomático
# p/ pacotes sem programs.*). CLIs COM integração de shell (eza/fzf/zoxide…) ficam
# no cli.nix via programs.*. `unstable.*` = canal bleeding-edge (overlay do flake).
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gh # GitHub CLI (auth/push via HTTPS + token)
    bitwarden-cli # `bw` — consultar/scriptar o cofre no terminal
    unstable.fastfetch # resumo do sistema (bleeding-edge: hardware/versões novas)
    unstable.claude-code # este assistente de código (bleeding-edge — evolui rápido)
    unstable.yt-dlp # baixa vídeo/áudio (unstable pq quebra quando os sites mudam)
  ];
}
