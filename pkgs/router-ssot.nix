# router-ssot: it fails when the router's mirrored UCI disagrees with the SSOT this repo declares.
# Rule 11 asks for one owner per value, and the router is the one place Nix does not reach, so until
# this existed the only guard was "keep it in sync by hand": docs/notes/repo/router-ssot.md
{ writers }:

writers.writePython3Bin "router-ssot"
  {
    libraries = [ ];
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  }
  ''
    """Fail when the router's mirrored UCI disagrees with the SSOT declared in this repo."""
    import ipaddress
    import os
    import re
    import subprocess
    import sys

    ROOT = os.environ.get("ROUTER_SSOT_ROOT") or subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()

    MIRROR = "router/uci"


    def read(rel):
        try:
            with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
                return fh.read()
        except OSError:
            return ""


    def uci(name):
        """One mirrored config as {key: [values]}. A list option carries several quoted values."""
        out = {}
        for line in read(f"{MIRROR}/{name}.conf").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, raw = line.partition("=")
            found = re.findall(r"'([^']*)'", raw)
            out[key.strip()] = found or [raw.strip()]
        return out


    def anon(conf, kind):
        """The ANONYMOUS sections of one kind, as {index: {option: value}}."""
        out = {}
        for key, vals in conf.items():
            m = re.match(r"\w+\.@" + kind + r"\[(\d+)\]\.(\w+)$", key)
            if m:
                out.setdefault(m.group(1), {})[m.group(2)] = vals[0]
        return out


    def named(conf, prefix):
        """The NAMED sections whose name starts with prefix, as {name: {option: value}}."""
        out = {}
        for key, vals in conf.items():
            m = re.match(r"\w+\.(" + prefix + r"\w*)\.(\w+)$", key)
            if m:
                out.setdefault(m.group(1), {})[m.group(2)] = vals[0]
        return out


    def strip_comment(line):
        """Drop a trailing Nix comment, ignoring a `#` that lives INSIDE a quoted string."""
        out, quoted = [], False
        for i, ch in enumerate(line):
            if ch == '"' and (i == 0 or line[i - 1] != "\\"):
                quoted = not quoted
            if ch == "#" and not quoted:
                break
            out.append(ch)
        return "".join(out)


    def nix_list(text, name):
        """The quoted strings of a Nix list literal, which is how the repo declares its blocks.
        Comments are stripped FIRST: the prose next to moonlightSources quotes `the FAI range`, and
        reading that as an entry is exactly the false positive this checker existed 5 minutes to find."""
        m = re.search(name + r"\s*=\s*\[(.*?)\];", text, re.S)
        if not m:
            return []
        body = "\n".join(strip_comment(line) for line in m.group(1).splitlines())
        return re.findall(r'"([^"]+)"', body)


    def declared():
        """Every value this repo owns and the router repeats. ANCHORED, so a rename fails here
        loudly instead of turning a check into a no-op that passes for the wrong reason."""
        subnets = read("system/net/subnets.nix")
        sunshine = read("system/services/sunshine.nix")

        out = {"subnets": {}}
        for name, body in re.findall(r"(\w+Subnet)\s*=\s*lib\.mkOption\s*\{(.*?)\};", subnets, re.S):
            m = re.search(r'default\s*=\s*"([^"]+)"', body)
            if m:
                out["subnets"][name] = m.group(1)

        base = re.search(r"basePort\s*=\s*(\d+)", sunshine)
        out["base_port"] = int(base.group(1)) if base else 0
        out["moonlight_sources"] = nix_list(sunshine, "moonlightSources")

        # The host's own LAN address has no option of its own: it appears once in the Nix tree, as
        # the CSRF origin, and 19 times in the mirror. That asymmetry is why it is checked and not
        # generated, and the day it earns an option this anchor is the thing to move.
        host = re.search(r'csrf_allowed_origins\s*=\s*"https://([\d.]+):', sunshine)
        out["host_ip"] = host.group(1) if host else ""

        out["fai_subnets"] = nix_list(read("system/net/fai-gateway.nix"), "faiSubnets")
        ssh = re.search(r"ports\s*=\s*\[\s*(\d+)\s*\]", read("system/net/network.nix"))
        out["ssh_port"] = ssh.group(1) if ssh else ""
        out["ssh_hosts"] = set(re.findall(r'HostName\s*=\s*"([\d.]+)"', read("home/shell/ssh.nix")))
        return out


    def check_mirror(_d, conf):
        """A missing mirror would make every check below pass for the wrong reason."""
        if "network.lan.ipaddr" not in conf["network"]:
            return [("mirror", f"{MIRROR}/network.conf has no network.lan.ipaddr",
                     "run `router-sync pull`: the mirror is missing or truncated")]
        return []


    def check_subnets(d, conf):
        """The router's own addresses have to live inside the subnets the repo declares."""
        out = []
        for opt, key in (("lanSubnet", "network.lan.ipaddr"), ("vpnSubnet", "network.wg0.addresses")):
            want, vals = d["subnets"].get(opt), conf["network"].get(key)
            if not want or not vals:
                out.append(("subnet", f"could not read {opt} or {key}",
                            "an anchor moved: fix this checker, do not delete the check"))
                continue
            if ipaddress.ip_interface(vals[0]).ip not in ipaddress.ip_network(want):
                out.append(("subnet", f"{key} is {vals[0]}, outside my.net.{opt} ({want})",
                            "both describe the same network: align the router or the option"))
        return out


    def moonlight(conf):
        """The Moonlight-* redirects, the hand kept mirror of moonlightSources."""
        return [s for s in anon(conf["firewall"], "redirect").values()
                if s.get("name", "").startswith("Moonlight-")]


    def check_moonlight_sources(d, conf):
        """SET EQUALITY, in both directions, and the empty case is the point now: the direct path was
        retired on 19/08/2026, so the repo declares NO sources and the router must forward NOTHING.
        A redirect that reappears on the device is drift the same way a missing one used to be."""
        on_router = sorted({s.get("src_ip", "") for s in moonlight(conf)})
        in_repo = sorted(d["moonlight_sources"])
        if on_router != in_repo:
            return [("moonlight", f"router src_ip is {on_router}, moonlightSources is {in_repo}",
                     "the router forwards exactly what the repo declares: a redirect the repo does not know "
                     "about is a port open to UFSCar, and one declared without the redirect is `Moonlight "
                     "does not connect`")]
        return []


    def check_moonlight_ports(d, conf):
        """The ports are DERIVED from one base in the module, so a redirect repeats a derivation.
        With no source declared there is nothing to forward, so the expected set is EMPTY and any
        port on the device is a finding."""
        base = d["base_port"]
        want = set() if not d["moonlight_sources"] else {
            ("tcp", str(base - 5)), ("tcp", str(base)), ("tcp", str(base + 21)),
            ("udp", f"{base + 9}-{base + 11}"),
        }
        got = {(s.get("proto", ""), s.get("src_dport", "").replace(":", "-")) for s in moonlight(conf)}
        out = []
        if got != want:
            out.append(("moonlight", f"redirect ports are {sorted(got)}, basePort derives {sorted(want)}",
                        "the offsets live in system/services/sunshine.nix, and an EMPTY expectation means "
                        "the direct path is retired, so the device should forward nothing"))
        for s in moonlight(conf):
            if s.get("src_dport", "") != s.get("dest_port", ""):
                out.append(("moonlight", f"{s.get('name')} maps {s.get('src_dport')} to {s.get('dest_port')}",
                            "Sunshine derives every port from one base, so a translated port breaks the client"))
        return out


    def check_moonlight_dest(d, conf):
        """A redirect that survives a DHCP change by pointing at the wrong host answers nothing."""
        bad = sorted(s.get("name", "") for s in moonlight(conf) if s.get("dest_ip") != d["host_ip"])
        if bad:
            return [("moonlight", f"these do not point at {d['host_ip']}: {bad}",
                     "the host address is the CSRF origin in system/services/sunshine.nix")]
        return []


    def check_fai_routes(d, conf):
        """THEIR ranges arrive in the IPCP and can change, so the two lists have to agree."""
        out = []
        for name, s in sorted(named(conf["network"], "fai_r").items()):
            target, mask = s.get("target", ""), s.get("netmask", "")
            if target and mask:
                cidr = str(ipaddress.ip_network(f"{target}/{mask}", strict=False))
                if cidr not in d["fai_subnets"]:
                    out.append(("fai", f"{name} routes {cidr}, which faiSubnets does not list",
                                "system/net/fai-gateway.nix holds that list"))
            if s.get("gateway") and s.get("gateway") != d["host_ip"]:
                out.append(("fai", f"{name} points at {s.get('gateway')}, not {d['host_ip']}",
                            "the gateway for the FAI ranges is this host, where nxBender runs"))
        return out


    def check_ssh_port(d, conf):
        """The exposed port is one number in two configs, and the repo owns it."""
        port = d["ssh_port"]
        hits = [s for s in anon(conf["firewall"], "redirect").values()
                if s.get("dest_ip") == d["host_ip"] and s.get("dest_port") == port]
        if not hits:
            return [("ssh", f"no redirect sends {port} to {d['host_ip']}",
                     "services.openssh.ports in system/net/network.nix owns that number")]
        return []


    def check_split_dns(d, conf):
        """A split-DNS answer pointing at an address no host here claims is drift with no symptom
        until somebody uses the name. It caught a poisoned anchor once already."""
        lan = ipaddress.ip_network(d["subnets"].get("lanSubnet", "0.0.0.0/0"))
        known = {d["host_ip"]} | {h for h in d["ssh_hosts"] if ipaddress.ip_address(h) in lan}
        out = []
        for entry in conf["dhcp"].get("dhcp.@dnsmasq[0].address", []):
            ip = entry.rsplit("/", 1)[-1]
            try:
                inside = ipaddress.ip_address(ip) in lan
            except ValueError:
                continue
            if inside and ip not in known:
                out.append(("dns", f"{entry} answers {ip}, which no host in this repo declares",
                            "declare the host or fix the entry: a wrong split-DNS only breaks by name"))
        return out


    CHECKS = (check_subnets, check_moonlight_sources, check_moonlight_ports, check_moonlight_dest,
              check_fai_routes, check_ssh_port, check_split_dns)


    def main():
        conf = {name: uci(name) for name in ("network", "firewall", "dhcp")}
        d = declared()

        # A stale mirror is reported ALONE: every other finding would be about the wrong file.
        findings = check_mirror(d, conf) or [f for check in CHECKS for f in check(d, conf)]

        if findings:
            print(f"\nrouter-ssot: {len(findings)} disagreement(s) between this repo and the router\n",
                  file=sys.stderr)
            for kind, detail, fix in findings:
                print(f"  {kind}: {detail}", file=sys.stderr)
                print(f"    -> {fix}", file=sys.stderr)
            print("\nThe mirror is READ-ONLY: fix the device with uci, then `router-sync pull`.",
                  file=sys.stderr)
            return 1

        print(f"router-ssot: {len(CHECKS)} checks, the mirror agrees with the repo")
        return 0


    sys.exit(main())
  ''
