# ═══════════════════════════════════════════════════════════════════════════
# THE OpenWrt ROUTER: what the repo can manage to know about it.
#
# The device (a Cudy WR3000, OpenWrt) is the piece of infrastructure Nix does NOT reach: 6 MB of
# flash and 128 MB of RAM put NixOS out of scale by orders of magnitude. So the ambition here is
# not "declarative", it is VISIBLE and RECOVERABLE, which is what was really missing. The 750
# lines of UCI lived only on the device, with no review, no history and nobody knowing when they
# changed.
#
# `router-sync pull` mirrors the UCI into ../../router/uci/*.conf, one file per config, with the
# secrets REDACTED (rule 12). `router-sync diff` compares and exits 1 if they diverge; it is what
# keeps the copy from rotting into a lie.
#
# IT DOES NOT PUSH CONFIG, on purpose. Writing UCI over SSH requires commit-confirm (apply,
# schedule a rollback, confirm if there is still access), otherwise one wrong network or firewall
# line locks you out and the way back is failsafe mode with PHYSICAL access. The decision about
# the push tool (nuci/Dewclaw/our own) is open in the TODO in docs/open-items.md; this module
# delivers the half with no risk.
#
# WHAT `sysupgrade` ALREADY PRESERVES: 38 entries in keep.d, measured on 08/08/2026. The WHOLE
# `/etc/config/`, `/etc/profile.d/`, `/etc/dropbear/`, passwd/shadow/group AND ALSO
# `/etc/sudoers.d/`. What stays out is only `/home/` (the SSH key and `~/bin/owfetch`) and
# `/etc/sysupgrade.conf` ITSELF. That last one is the trap: `list_static_conffiles` reads the
# paths listed INSIDE it but does not include it, so without listing itself the 1st upgrade
# preserves what you asked for and the 2nd loses everything.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

let
  # Python and not shell: the secret redaction parses per option and the decision is fail-safe (it
  # redacts by default and releases what it recognizes). In shell that would become sed with a
  # negative regex, which is exactly the kind of thing that gets it wrong in silence.
  routerSyncPy = pkgs.writeText "router-sync.py" (builtins.readFile ../../scripts/router-sync.py);
in
{
  # The wrapper: the logic lives in the build (rule 7), the runtime is one line. `openssh` in
  # runtimeInputs because the script calls `ssh`; without it, it would depend on the user's PATH,
  # which is exactly what rule 7 wants to avoid.
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "router-sync";
      runtimeInputs = with pkgs; [
        python3
        openssh
        git # it finds the repo's root (the same idiom as scripts/sync-secrets.sh)
      ];
      text = ''exec python3 ${routerSyncPy} "$@"'';
    })
  ];
}
