# Sunshine — servidor de streaming de tela/desktop remoto (cliente = Moonlight). É
# a forma recomendada de acesso remoto no Hyprland/Wayland: captura via wlr-screencopy
# (o `wlr`, auto-selecionado) e encoda na GPU. O Arc B580 tem encoder AV1/HEVC (VA-API)
# → stream fluido e de baixa latência. Chega-se no Sunshine PELA tailnet (Tailscale),
# não pela LAN/internet (openFirewall=false → só a interface tailscale0, que é trusted).
#
# APRENDIZADO (jul/2026, debug longo): "tela preta no Moonlight" era o wlr capturando o
# monitor DPMS-OFF (apagado) — NÃO regressão de versão nem encoder. Captura funciona
# desde que o monitor esteja LIGADO durante o stream (por isso o guard streamBegin). O
# `capture=kms` seria uma alternativa, mas o kmsgrab NÃO enumera no driver `xe`. CUIDADO:
# alternar dpms COM a captura+encode ativos deu engine-reset da GPU (xe RCS) — por isso o
# guard acorda a tela ANTES do stream (no prep-cmd), nunca no meio.
#
# Setup interativo (1x, do navegador de qualquer máquina na tailnet):
#   https://<ip-tailnet>:47990  → cria usuário/senha admin → pareia o Moonlight (PIN).
# O estado (clientes pareados) mora em ~/.config/sunshine (não declarável → é ESTADO).
#
# GUARD DE IDLE (conflito com o hypridle): a captura é do monitor FÍSICO via wlr. Se
# o hypridle já tiver dado `dpms off` (home/desktop/lockscreen.nix, aos ~5min), o output
# está em standby → conectar do Moonlight pega TELA PRETA (a conexão não acorda a tela;
# só input, e há bugs de black-screen/crash no dpms off do Hyprland). Fix idiomático:
# global_prep_cmd (do/undo no início/fim do stream) → ao conectar ACORDA a tela e PAUSA
# o hypridle (não desliga no meio do stream); ao desconectar, RELIGA o hypridle. Assim o
# monitor segue desligando aos 5min quando estou fora, mas o acesso remoto sempre funciona.
{ pkgs, ... }:

let
  # Início do stream: acorda todos os monitores (dpms on, no-op se já ligados) e para o
  # hypridle p/ não travar/desligar a tela no meio da sessão remota. `|| true`: um passo
  # falho nunca aborta o stream (prep-cmd que falha cancela o app no Sunshine).
  streamBegin = pkgs.writeShellScript "sunshine-stream-begin" ''
    # Para o hypridle PRIMEIRO (não reapaga a tela no meio do stream) e SÓ ENTÃO
    # acorda o monitor — ordem importa p/ não haver corrida com um timeout de idle.
    ${pkgs.systemd}/bin/systemctl --user stop hypridle.service || true
    ${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms("on")' || true
    # Settle: o painel físico leva ~1-2s p/ acender e voltar a emitir frames. Sem esta
    # pausa a captura wlr começa numa tela ainda escura e LATCHA em PRETO (não recupera
    # sem uma transição). Roda no prep-cmd do Sunshine, que espera o `do` terminar.
    ${pkgs.coreutils}/bin/sleep 2 || true
  '';
  # Fim do stream: religa o hypridle → volta o ciclo normal (lock+dpms off aos 5min).
  streamEnd = pkgs.writeShellScript "sunshine-stream-end" ''
    ${pkgs.systemd}/bin/systemctl --user start hypridle.service || true
  '';
in
{
  services.sunshine = {
    enable = true;
    capSysAdmin = true; # cap p/ captura KMS (mirror da sessão física do Hyprland)
    autoStart = true; # sobe junto da sessão gráfica (serviço --user, WantedBy graphical-session)
    openFirewall = false; # NÃO abre na LAN/internet; acesso só pela tailnet (tailscale0 trusted)
    settings = {
      sunshine_name = "nixos-sandisk"; # nome que aparece no Moonlight
      # NÃO forçar capture=kms: o kmsgrab NÃO enumera no driver `xe` (Battlemage) →
      # "Unable to find display" e o serviço nem streama. Deixa auto = `wlr` (funciona
      # DESDE QUE o monitor esteja ligado — ver o guard streamBegin abaixo).
      # Acesso vem pela tailnet (IP 100.x, que o Sunshine classifica como WAN) →
      # "wan" p/ não bloquear o web UI. NÃO é exposição real: o firewall só deixa a
      # tailscale0 (trusted) chegar aqui; LAN/internet continuam fechadas.
      origin_web_ui_allowed = "wan";
      # CSRF: libera as origens da tailnet (IP + nome MagicDNS). Sem isto, criar o
      # usuário/salvar pelo web UI é bloqueado quando o host != localhost.
      csrf_allowed_origins = "https://100.92.126.90:47990,https://nixos-sandisk.tailf2731d.ts.net:47990";
      # Guard de idle: do/undo acordam a tela + pausam o hypridle durante o stream (ver
      # header). JSON no sunshine.conf; vale p/ TODOS os apps (inclui o "Desktop" remoto).
      global_prep_cmd = builtins.toJSON [
        { do = "${streamBegin}"; undo = "${streamEnd}"; }
      ];
    };
  };
}
