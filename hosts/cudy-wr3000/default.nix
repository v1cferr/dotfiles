# The router's facts, written ONCE: it runs OpenWrt, so this is data and not a NixOS module. The
# desktop wires it as my.router, the flake hands it to the checkers: docs/notes/repo/router-ssot.md
{
  address = "192.168.1.1"; # the LAN gateway, and the SSH target of router-sync and `ssh router`
  sshUser = "v1cferr";
  # Repo-relative and not a path: router-sync WRITES it in the working tree, never in the store.
  mirror = "hosts/cudy-wr3000/uci";
}
