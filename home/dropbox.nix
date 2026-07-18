# ═══════════════════════════════════════════════════════════════════════════
# DROPBOX — pasta ~/Dropbox sincronizada (cofre do Obsidian + documentos).
#
# Exceção consciente à regra "home/ não instala": services.dropbox é um SERVIÇO
# do usuário (systemd --user), não um pacote no environment.systemPackages. O
# módulo do home-manager já traz o dropbox-cli e sobe o daemon — aqui só HABILITA.
#
# Por que o cliente oficial e não Maestral: o home-manager tem módulo oficial
# mantido pra este; o Maestral foi arquivado upstream, não tem módulo e tem bug
# conhecido no NixOS (perde config no logout, nixpkgs#307898).
#
# Uso previsto: só notas .md do Obsidian e documentos (plano grátis, 2 GB) —
# nada de binário/arquivo grande. O repo restic (backup pesado) NÃO vem pra cá.
#
# 1º uso: após o rebuild o daemon sobe e imprime uma URL pra VINCULAR a conta
#   systemctl --user status dropbox   # copie o link, autorize no navegador
# O cliente baixa o próprio binário em ~/.dropbox-dist (estado, fora do Nix) —
# é a parte imperativa que o Dropbox impõe; o resto (habilitar/subir) é declarado.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  services.dropbox.enable = true; # pasta padrão: ~/Dropbox
}
