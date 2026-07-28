# Sunshine — servidor de streaming de tela/desktop remoto (cliente = Moonlight). É
# a forma recomendada de acesso remoto no Hyprland/Wayland: captura por KMS (contorna
# as limitações do Wayland) e encoda por GPU. O Arc B580 tem encoder AV1/HEVC (VA-API)
# → stream fluido e de baixa latência. Chega-se no Sunshine PELA tailnet (Tailscale),
# não pela LAN/internet (openFirewall=false → só a interface tailscale0, que é trusted).
#
# Setup interativo (1x, do navegador de qualquer máquina na tailnet):
#   https://<ip-tailnet>:47990  → cria usuário/senha admin → pareia o Moonlight (PIN).
# O estado (clientes pareados) mora em ~/.config/sunshine (não declarável → é ESTADO).
#
# GUARD DE IDLE (conflito com o hypridle): a captura é do monitor FÍSICO via KMS. Se
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
    ${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms("on")' || true
    ${pkgs.systemd}/bin/systemctl --user stop hypridle.service || true
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
