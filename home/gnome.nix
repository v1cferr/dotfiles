# Ajustes do GNOME no nível do USUÁRIO (dconf). O GNOME/Wayland ignora o
# services.xserver.xkb do sistema na sessão do usuário — o layout aqui é o que
# vale de fato ao digitar. ('xkb','br') = ABNT2 (variante padrão do layout br).
{ lib, ... }:

{
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      sources = [ (lib.hm.gvariant.mkTuple [ "xkb" "br" ]) ];
      xkb-options = [ "terminate:ctrl_alt_bksp" ];
    };

    # Não deixar o GNOME suspender por inatividade (par do systemd.targets no
    # system/ — este cobre a sessão gráfica; aquele, o sistema todo).
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-battery-type = "nothing";
    };
  };
}
