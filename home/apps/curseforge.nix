# ═══════════════════════════════════════════════════════════════════════════
# CurseForge: the official Minecraft modpack app. The PACKAGE (the official AppImage,
# repackaged) lives in pkgs/curseforge.nix; this is the user side.
#
# It REPLACED prismlauncher on 14/08/2026: Prism imports a modpack .zip, but what keeps the
# library and UPDATES the pack is the CurseForge app, which is the real use here.
#
# And the swap SHRANK the system by 1.5 GiB, the opposite of what "native to Electron"
# suggests: 27.2 to 25.7 GiB, measured with `nix store diff-closures`. curseforge +340.2 MiB
# against prismlauncher -17.6 MiB and openjdk (8, 17, 21 and 25, which the Prism wrapper
# bundled) -1.8 GiB. The four JDKs left because NOBODY declares Java here: the provider is
# the app itself, which downloads its own JRE.
#
# THE JAVA IS THEIRS, NOT OURS, and declaring Java here has already been tried and does
# NOT work: the app only consults the JRE it manages itself (with three JREs installed, the
# agent log went on citing ITS java 18 times and ours ZERO times). When "Java Runtime
# Environment is missing or out of date" shows up, the cause is NOT a missing Java, it is
# their extractor losing the `+x` bit. And that same extractor takes down the game launch
# too, behind a different message ("An unexpected error occurred. Operation failed.",
# 15/08/2026). What fixes both is `curseforge-fix-perms` below, and the whole diagnosis
# lives in that package.
#
# Instances, mods and login are STATE (rule 6, so restic), not declaration:
#   ~/.config/CurseForge/  (config + session)   ~/Documents/curseforge/  (instances)
#
# WHY THE SCHEMES ARE HERE AND ARE NOT OPTIONAL: the app tries to register itself as the
# handler for `curseforge://`/`cfauth://` at RUNTIME (Electron setAsDefaultProtocolClient),
# and that will NEVER work on this system: ~/.config/mimeapps.list is managed by home-manager
# and points into /nix/store, which is read-only (rule 14: Nix is the owner). Measured on
# 14/08/2026, the app log says exactly that on startup:
#     [BackgroundController] Failed subscribing app protocol.
#     [LoginService] Failed to register login scheme 'cfauth'. This might create issues
#                    with the login process..
# And `cfauth://` is no detail: it is the LOGIN callback (the app opens the browser and waits
# for the redirect back). With no handler, the login comes back to nothing. The declarative
# association below is the registration the app cannot make on its own: the package's
# .desktop already declares the three schemes in MimeType, here we only say that IT is the
# default.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, lib, ... }:

let
  curseforge = "curseforge.desktop";
in
{
  home.packages = [
    pkgs.curseforge # the official AppImage, repackaged (./pkgs), unfree
    # Recomputes version+hash of pkgs/curseforge.nix. On the PATH because what calls it by
    # name is the `update` alias (home/shell/zsh.nix), the same arrangement as vscode-bump.
    pkgs.curseforge-bump
    # Gives back the `+x` on what the app unpacks (see the package). On the PATH because the
    # download that breaks can happen IN THE MIDDLE of a session, by which point the
    # activation below has already run: then it is a matter of running `curseforge-fix-perms`
    # and reopening the app, with no rebuild to wait for.
    pkgs.curseforge-fix-perms
  ];

  # What the app unpacks is STATE (rule 6) and it is the app that writes it (rule 14), hence
  # an IDEMPOTENT activation instead of managing the files: Nix does not become the owner of
  # anything here, it only undoes a known bit of damage. `writeBoundary` because the package
  # has to be in the profile first.
  home.activation.curseforgeFixPerms = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe pkgs.curseforge-fix-perms}
  '';

  # Merges with the associations from home/desktop/xdg.nix (browser) and media.nix.
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/cfauth" = curseforge; # the login callback, the one that matters most
    "x-scheme-handler/curseforge" = curseforge; # the "Install" button on the modpack site
    "x-scheme-handler/curseforge-checkout" = curseforge; # buying a premium add-on
  };
}
