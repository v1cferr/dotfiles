# ═══════════════════════════════════════════════════════════════════════════
# ROTEADOR OpenWrt — o que o repo consegue saber sobre ele.
#
# O aparelho (Cudy WR3000, OpenWrt) é a peça de infra que o Nix NÃO alcança: 6 MB
# de flash e 128 MB de RAM põem NixOS fora de escala por ordens de grandeza. Então
# a ambição aqui não é "declarativo", é VISÍVEL e RECUPERÁVEL — que era o que
# faltava de verdade. As 750 linhas de UCI viviam só no aparelho, sem revisão,
# sem histórico e sem ninguém saber quando mudavam.
#
# `router-sync pull` espelha o UCI em ../../router/uci/*.conf, um arquivo por
# config, com os segredos REDIGIDOS (regra 12). `router-sync diff` compara e sai 1
# se divergir — é ele que impede a cópia apodrecer e virar mentira.
#
# ⚠️ NÃO EMPURRA CONFIG, de propósito. Escrever UCI por SSH exige commit-confirm
# (aplica → agenda rollback → confirma se ainda houver acesso), senão uma linha
# errada de rede ou firewall tranca você fora e a saída é modo failsafe com acesso
# FÍSICO. A decisão sobre a ferramenta de push (nuci/Dewclaw/própria) está aberta
# no TODO de docs/ANOTACOES.md; este módulo entrega a metade sem risco.
#
# O QUE O `sysupgrade` JÁ PRESERVA, medido em 08/08/2026 no keep.d do aparelho:
# `/etc/config/` INTEIRO, `/etc/profile.d/`, `/etc/dropbear/` e passwd/shadow/group.
# O que NÃO sobrevive é `/etc/sudoers.d/` e `/home/` — daí a chave SSH e o
# `~/bin/owfetch` precisarem entrar no `/etc/sysupgrade.conf` do roteador.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

let
  # Python e não shell: a redação de segredo faz parsing por opção e a decisão é
  # fail-safe (redige por default, libera o que reconhece). Em shell isso viraria
  # sed com regex negativo — exatamente o tipo de coisa que erra em silêncio.
  routerSyncPy = pkgs.writeText "router-sync.py" (builtins.readFile ../../scripts/router-sync.py);
in
{
  # Wrapper: a lógica mora no build (regra 7), o runtime é uma linha. `openssh` em
  # runtimeInputs porque o script chama `ssh` — sem isso ele dependeria do PATH do
  # usuário, que é justamente o que a regra 7 quer evitar.
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "router-sync";
      runtimeInputs = with pkgs; [
        python3
        openssh
        git # acha a raiz do repo (mesmo idioma do scripts/sync-secrets.sh)
      ];
      text = ''exec python3 ${routerSyncPy} "$@"'';
    })
  ];
}
