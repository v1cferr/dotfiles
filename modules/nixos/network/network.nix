# NETWORK: NetworkManager, BBR and the kernel's redirect hardening, for every host.
# The four BBR batteries and the measured sysctl defaults: docs/notes/network/network.md
{ ... }:

{
  networking.networkmanager.enable = true;

  # Kept for the RETRANSMISSION, not for throughput: at the same RTT the two tie at ~55 Mbps in
  # the FAI tunnel and only the loss changes, 0.38% to 0.10-0.26%. Four batteries: network.md.
  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq"; # BBR paces its packets; fq is what executes the pacing
    # Hardening, only what the kernel defaults left open (measured, network.md): no ICMP redirect
    # in or out, and kernel pointers hidden from root too. rp_filter stays 0: checkReversePath does it.
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "kernel.kptr_restrict" = 2;
  };
}
