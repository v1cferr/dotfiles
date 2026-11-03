# nethogs as a capability wrapper: the bar's network panel lists the apps moving traffic without
# a root daemon, and only wheel can run it. Why these four capabilities: docs/notes/desktop/bar.md
{ pkgs, ... }:

let
  inherit (pkgs) nethogs;
in
{
  security.wrappers.nethogs = {
    source = "${nethogs}/bin/nethogs";
    owner = "root";
    group = "wheel";
    permissions = "u+rx,g+x";
    # Capture (net_raw, net_admin) plus mapping a socket to its process for every user (dac, ptrace).
    capabilities = "cap_net_admin,cap_net_raw,cap_dac_read_search,cap_sys_ptrace+ep";
  };
}
