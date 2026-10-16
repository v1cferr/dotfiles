# Tor, CLIENT ONLY and ON DEMAND: a SOCKS5 on 127.0.0.1:9050 that `mega-dl --tor` raises, never a
# relay or exit. Why on demand, and a native proxy over torsocks: docs/notes/apps/mega.md
{ config, lib, ... }:

{
  services.tor = {
    enable = config.my.services.tor;
    client.enable = true; # this is what opens the SOCKS5 on 127.0.0.1:9050
    settings = {
      ClientOnly = true; # it locks the role: never a relay, never an exit
      SafeSocks = true; # DNS resolved outside Tor is an error, not a silent leak
    };
  };

  # The unit exists, but nothing pulls it in at boot: a circuit open all day for a rare use is
  # exposure (and a purple badge) with no consumer.
  systemd.services.tor.wantedBy = lib.mkIf config.my.services.tor (lib.mkForce [ ]);

  # Lets the user start and stop ONLY tor.service without a password, so `mega-dl --tor` can
  # raise it and take it down itself. Same shape as the vpn-* rule in vpn.nix.
  security.polkit.extraConfig = lib.mkIf config.my.services.tor ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "v1cferr" &&
          action.lookup("unit") == "tor.service") {
        return polkit.Result.YES;
      }
    });
  '';
}
