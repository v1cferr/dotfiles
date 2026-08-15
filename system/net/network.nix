# ═══════════════════════════════════════════════════════════════════════════
# NETWORK AND REMOTE ACCESS: NetworkManager, SSH (exposed), fail2ban, dynamic DNS and "never
# suspend". The theme: this is a machine for remote access over SSH.
# ═══════════════════════════════════════════════════════════════════════════
{ config, ... }:

{
  # ── Network ────────────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

  # ── The home VPN: the WireGuard range is TRUSTED ───────────────────────────
  # The WireGuard server is the ROUTER (OpenWrt), not this machine, so there is NO local `wg0`
  # interface to put in `trustedInterfaces`. The peers' traffic arrives over the LAN with
  # source 10.10.10.x, and the trust has to be by SOURCE.
  #
  # This REPLACES the `trustedInterfaces = [ "tailscale0" ]` that died along with Tailscale
  # (08/08/2026), and it is what keeps Sunshine reachable THROUGH THE TUNNEL, since it runs
  # with `openFirewall = false` on purpose. Whoever deletes this has to open its ports.
  #
  # It is no longer the only path, and the previous sentence ("without this rule it is
  # unreachable from everywhere") expired on 10/08/2026: the direct access from UFSCar, with no
  # VPN, has its own rules in ../services/sunshine.nix. The two coexist on purpose: this one
  # covers the phone and any new peer; the one over there covers the FAI notebook, where adding
  # a third VPN client would be a routing conflict. Deleting this one does NOT take down
  # Moonlight from UFSCar, and deleting the other one does NOT take down the tunnel's.
  #
  # `-I nixos-fw 1` and not `-A`. CORRECTION (08/08/2026): this comment used to say that "the
  # chain ends in a refuse, so `-A` is never reached", and that is FALSE for extraCommands.
  # Read in the GENERATED firewall-start, it is injected BEFORE the
  # `-A nixos-fw -j nixos-fw-log-refuse`, so `-A` would work. The sentence only holds for a
  # rule typed BY HAND into a firewall that is already up. The `-I 1` is still the right thing
  # for another reason: it is what reproduces the trustedInterfaces semantics, since the whole
  # range passes before ANY other decision in the chain.
  # (The backend here is iptables: `networking.nftables.enable = false`.)
  networking.firewall = {
    extraCommands = ''
      iptables -I nixos-fw 1 -s ${config.my.net.vpnSubnet} -j nixos-fw-accept
    '';
    # Without this, a firewall `reload` stacks duplicates of the rule above.
    extraStopCommands = ''
      iptables -D nixos-fw -s ${config.my.net.vpnSubnet} -j nixos-fw-accept 2>/dev/null || true
    '';
  };

  # ── SSH (mirrors Arch: port 2222, root off, password as a fallback) ────────
  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    openFirewall = true; # opens 2222 in the firewall
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
    };
  };

  # ── Never suspend ────────────────────────────────────────────────────────
  # It is a remote access desktop (SSH). If it suspends, SSH drops and you cannot reach it from
  # another PC. This disables every sleep target.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # ── Wake-on-LAN, the counterpart of "never suspend": if the machine IS off ──
  # FOUND ON 10/08/2026, and the symptom was invisible: the router has ALL the pieces to wake
  # this PC (the `/usr/bin/wake-desktop` script, its NOPASSWD rule, and the target MAC
  # `7c:10:c9:a1:f4:e5`, which matches this enp7s0) and nothing happened, because the RECEIVING
  # end was disarmed. Measured: `Wake-on: d`, with `Supports Wake-on: pumbg` (the `g` for magic
  # packet exists on the card). Three correct pieces pointing at a fourth that does not listen:
  # it raises no error anywhere, it just does not wake.
  #
  # DECLARATIVE AND NOT `ethtool -s enp7s0 wol g`: the r8169 RESETS WoL on every boot, so the
  # imperative form is lost on the next reboot, which is exactly when it is needed. This option
  # becomes `linkConfig.WakeOnLan` (nixos/modules/tasks/network-interfaces.nix), applied by
  # udev on every link up.
  #
  # A CONTRAST with the `wake-workstation` in ../../home/net/fai-workstation.nix, which solves
  # the SAME problem and could not be declared: there the receiver is somebody else's Ubuntu and
  # the fix is netplan by hand, noted in a comment. Here the receiver is this machine.
  #
  # IT DOES NOT COVER A POWER OUTAGE, and that is the misunderstanding to avoid: a real cut
  # takes away the +5VSB and the NIC loses the armed register. For "the power went out" the
  # answer is the BIOS (*Restore on AC Power Loss* = Power On), which this repo does not reach.
  # WoL serves a NORMAL shutdown, which is the common case.
  #
  # NetworkManager has its own `connection.wol`. Its default is not to touch it, but if it
  # resets on a link change the symptom is WoL working right after boot and stopping later, and
  # that only shows up by actually powering off and sending the magic packet. A literal
  # `enp7s0` and not an option: a single consumer (rule 11 asks for 2+).
  networking.interfaces.enp7s0.wakeOnLan.enable = true;

  # ── fail2ban: protects the SSH exposed to the internet ───────────────────
  # Port 2222 is open to the world (a 2222 port forward on OpenWrt) WITH passwords enabled, so
  # fail2ban is mandatory. It mirrors the Arch jail: it bans after 4 failures in 10min, for 1h,
  # and it never bans the LAN or loopback.
  services.fail2ban = {
    enable = true;
    bantime = "1h";
    # This holds for fail2ban's [DEFAULT], which means ALL jails inherit it, including
    # caddy-pos. 127.0.0.1/8 and ::1 are deliberately absent here: the nixpkgs module already
    # prepends them, and declaring them again came out duplicated in the generated jail.local.
    ignoreIP = [
      config.my.net.lanSubnet
      # The WireGuard range goes in with it: coming in from outside through the VPN and
      # mistyping the SSH password cannot ban your own way back.
      config.my.net.vpnSubnet
    ];
    jails.sshd.settings = {
      enabled = true;
      port = 2222;
      backend = "systemd"; # sshd logs to journald
      maxretry = 4;
      findtime = "10m";
    };
  };

  # ── Dynamic DNS (Cloudflare) ──────────────────────────────────────────────
  # It keeps ssh.<domain> pointing at the current public IP (which changes), so
  # `ssh …@ssh.<domain>` works from anywhere, with no VPN. The token stays OUT of git (through
  # sops). proxied=false means a DNS-only record (gray), because SSH does not go through
  # Cloudflare's HTTP proxy.
  #
  # This record is the whole zone's IP ANCHOR, and the only one the DDNS touches. The services
  # do NOT each get a record: the zone uses a `*.<domain>` WILDCARD CNAME pointing here, so a
  # new subdomain works with no DNS work at all, which is precisely the point of the wildcard.
  #
  # The IP published here IS this house's, and it DOES ANSWER from outside: the router has the
  # public one directly on `pppoe-wan` and forwards 80/443/2222. Proven on 08/08/2026 through
  # Cloudflare's edge (a temporary proxied record, and Caddy returned the catch-all 404 in
  # 0.39s). There was a CGNAT scare on 07/08 that proved FALSE; the diagnosis and the three
  # ways for the test to lie are in docs/history/2026/08-august.md.
  #
  # Do NOT add `*.<domain>` here. Tested on 07/08/2026: the tool only knows how to create and
  # update an A record, and the API refuses with code 81054 ("A CNAME record with that host
  # already exists"). The service enters a restart loop and exits 3. The wildcard has to stay a
  # CNAME, and it is its target that makes the zone follow the IP, not the DDNS.
  #
  # Do NOT TRUST `dig` FROM INSIDE THE HOUSE to audit this zone. The router does split-DNS of
  # `*.<domain>` to 192.168.1.10 and answers BEFORE any external server, including when you
  # point dig straight at the authoritative one (`dig @bruce.ns.cloudflare.com`). The symptom
  # is a TTL of 0 on an answer that should come from Cloudflare. It cost an entire investigation
  # on 07/08/2026: the zone was RIGHT and looked broken. To see the real DNS, go out through DoH
  # (HTTPS, which the router does not intercept):
  #   curl -s -H 'accept: application/dns-json' \
  #     'https://cloudflare-dns.com/dns-query?name=ssh.<domain>&type=A' | jq
  #
  # The cache (/var/lib/cloudflare-dyndns/ip.cache) compares the current IP against what IT
  # wrote last, never against the real record, so a change made through the dashboard leaves it
  # blind ("Every domain is up-to-date", without calling the API). Deleting it forces a real
  # write.
  #
  # The name comes from `my.net.domain` (an SSOT, rule 11, ./domain.nix), never a literal:
  # Caddy and the fail2ban jails read the SAME option.
  services.cloudflare-dyndns = {
    enable = config.my.services.cloudflare-ddns;
    apiTokenFile = config.sops.secrets.cloudflare_ddns_token.path;
    domains = [ "ssh.${config.my.net.domain}" ];
    proxied = false;
    ipv4 = true;
    ipv6 = false;
  };

  # WAITING FOR THE NETWORK FOR REAL. The nixpkgs module orders only by `network.target`
  # (services/networking/cloudflare-dyndns.nix:79), and that target does NOT mean "there is
  # internet", it means "the network stack was started". What means connectivity is
  # `network-online.target`, and it requires BOTH ends: the `wants` (otherwise the target is not
  # even pulled in) and the `after` (otherwise there is no ordering).
  #
  # MEASURED on the 01/08 boot: the service came up at T+3s and network-online was only ready
  # at T+9.8s (NetworkManager-wait-online takes 6.5s waiting for DHCP). The result, EVERY boot:
  # the four "what is my IP" APIs came back unreachable, it DELETED the cache
  # (`Deleting cache at: …/ip.cache`) and exited with status 2. The 5 min timer fixed it
  # afterwards, so this never showed up as broken, only as a `failed` at boot that we learned to
  # ignore. The real cost was ssh.v1cferr.dev pointing at the old IP at the WORST possible
  # moment: right after a power outage, which is precisely when the public IP tends to change
  # and when you want to get in from outside.
  # THERE WAS A SECOND CAUSE, and it DIED with Tailscale (08/08/2026): /etc/resolv.conf pointed
  # at 100.100.100.100, served by tailscaled itself, which came up 11ms AFTER this service, so
  # the four "what is my IP" APIs failed on resolution, not on routing. That required an
  # `after = tailscaled.service` that now has no target.
  # With the resolver back to normal, the DNS race does not exist.
  #
  # THE RETRY BELOW STAYS, and it is not residue: the first cause (DHCP taking ~6.5s after the
  # target) is independent of Tailscale and still holds. Tolerating the race and trying again is
  # more robust than guessing the ordering, and the Restart keeps the stale-IP window at <=20s
  # against the timer's <=5min. The StartLimit is the brake so it does not become an infinite
  # loop when the failure is real (an invalid token, Cloudflare down): 6 attempts in 5min and it
  # gives up, leaving the `failed` visible for the timer to take over later.
  systemd.services.cloudflare-dyndns = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "20s";
    };
    unitConfig = {
      StartLimitIntervalSec = "5m";
      StartLimitBurst = 6;
    };
  };
}
