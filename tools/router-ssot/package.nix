# router-ssot: it fails when the router's mirrored UCI disagrees with the SSOT this repo declares.
# Rule 11 asks for one owner per value, and Nix does not reach the router: docs/notes/repo/router-ssot.md
{
  writeShellApplication,
  ripgrep,
  jq,
  gnused,
  git,
  router,
}:

writeShellApplication {
  name = "router-ssot";
  # `$1` for rg -r and every `$name` of the jq program are literals in single quotes, on purpose.
  excludeShellChecks = [ "SC2016" ];
  runtimeInputs = [
    ripgrep
    jq
    gnused
    git
  ];
  text = ''
    root="''${ROUTER_SSOT_ROOT:-$(git rev-parse --show-toplevel)}"
    cd "$root"
    mirror="${router.mirror}"

    # The first match of a PCRE in a file, multiline, or nothing: an anchor that moved reads empty.
    first() { rg -U -o -P -r "$3" "$1" "$2" 2>/dev/null | head -n1 || true; }

    # The quoted strings of a Nix list literal, comments stripped FIRST: the prose next to
    # moonlightSources quotes `the FAI range`, and reading it as an entry was the first false positive.
    nix_list() {
      rg -U -o -P -m1 "(?s)$2\\s*=\\s*\\[.*?\\];" "$1" 2>/dev/null |
        sed -E 's/^(([^"#]|"([^"\\]|\\.)*")*)#.*/\1/' |
        rg -o -r '$1' '"([^"]+)"' || true
    }

    # Every value this repo owns and the router repeats. ANCHORED, so a rename fails loudly instead
    # of turning a check into a no-op that passes for the wrong reason.
    subnets=$(rg -U -o -P -r $'$1\t$2' \
      '(?s)(\w+Subnet)\s*=\s*lib\.mkOption\s*\{(?:(?!\};).)*?default\s*=\s*"([^"]+)"' \
      modules/nixos/network/subnets.nix 2>/dev/null || true)
    sunshine=modules/nixos/services/sunshine.nix
    ssh=modules/home/shell/ssh.nix
    # The host's LAN address has no option of its own: once in the tree, as the CSRF origin.
    # THREE ssh anchors, since two addresses left their `HostName` literal: docs/notes/repo/router-ssot.md
    hosts=$(
      rg -o -r '$1' 'HostName\s*=\s*"([\d.]+)"' "$ssh" 2>/dev/null || true
      first 'cesarHost\s*=\s*"([\d.]+)"' "$ssh" '$1'
      first '(?s)host\s*=\s*lib\.mkOption\s*\{.*?default\s*=\s*"([\d.]+)"' modules/home/network/t480.nix '$1'
      echo "${router.address}"
    )

    read_conf() { cat "$mirror/$1.conf" 2>/dev/null || true; }

    out=$(mktemp)
    trap 'rm -f "$out"' EXIT
    jq -nr \
      --arg network "$(read_conf network)" \
      --arg firewall "$(read_conf firewall)" \
      --arg dhcp "$(read_conf dhcp)" \
      --arg subnets "$subnets" \
      --arg base "$(first 'basePort\s*=\s*(\d+)' "$sunshine" '$1')" \
      --arg sources "$(nix_list "$sunshine" moonlightSources)" \
      --arg host "$(first 'csrf_allowed_origins\s*=\s*"https://([\d.]+):' "$sunshine" '$1')" \
      --arg faiSubnets "$(nix_list modules/nixos/network/fai-gateway.nix faiSubnets)" \
      --arg faiHosts "$(nix_list modules/nixos/network/fai-gateway.nix faiTunnelHosts)" \
      --arg sshPort "$(first 'ports\s*=\s*\[\s*(\d+)\s*\]' modules/nixos/network/network.nix '$1')" \
      --arg sshHosts "$hosts" \
      --arg mirror "$mirror" '
      def lines: split("\n") | map(select(length > 0));
      # One mirrored config as {key: [values]}. A list option carries several quoted values.
      def uci: lines | map(gsub("^\\s+|\\s+$"; "") | select(length > 0 and (startswith("#") | not) and contains("=")))
        | map(index("=") as $i | {key: (.[:$i] | gsub("^\\s+|\\s+$"; "")), value: (.[$i + 1:] as $raw
            | [$raw | scan("\u0027([^\u0027]*)\u0027")[0]] | if length > 0 then . else [$raw | gsub("^\\s+|\\s+$"; "")] end)})
        | from_entries;
      # The ANONYMOUS sections of one kind, {index: {option: value}}, in the order they appear.
      def anon($kind): reduce (to_entries[] | (.key | capture("^\\w+\\.@" + $kind + "\\[(?<i>\\d+)\\]\\.(?<o>\\w+)$")) as $m
        | {i: $m.i, o: $m.o, v: .value[0]}) as $e ({}; .[$e.i][$e.o] = $e.v);
      def named($prefix): reduce (to_entries[] | (.key | capture("^\\w+\\.(?<n>" + $prefix + "\\w*)\\.(?<o>\\w+)$")) as $m
        | {n: $m.n, o: $m.o, v: .value[0]}) as $e ({}; .[$e.n][$e.o] = $e.v);
      # A rule typed by hand is born NAMED (firewall.ssh_cesar), so anonymous ones alone would hide it.
      def sections($kind): . as $c | [anon($kind)[]] + [to_entries[] | select((.key | test("^\\w+\\.\\w+$")) and .value[0] == $kind)
        | .key as $k | reduce ($c | to_entries[] | select(.key | startswith($k + "."))) as $o ({}; .[$o.key | split(".") | last] = $o.value[0])];

      # IPv4 as integers. A non-IPv4 string is null, and null is inside nothing, like an IPv6 was.
      def ip: if type == "string" and test("^\\d{1,3}(\\.\\d{1,3}){3}$") then split(".") | map(tonumber)
        | if all(. <= 255) then .[0] * 16777216 + .[1] * 65536 + .[2] * 256 + .[3] else null end else null end;
      def net: split("/") | {base: (.[0] | ip), len: ((.[1] // "32") | tonumber)};
      def within($n): . != null and $n.base != null and (. / pow(2; 32 - $n.len) | floor) == ($n.base / pow(2; 32 - $n.len) | floor);
      def dotted: [(. / 16777216 | floor) % 256, (. / 65536 | floor) % 256, (. / 256 | floor) % 256, . % 256] | map(tostring) | join(".");
      def prefix: 32 - ((4294967296 - ip) | log2 | round);
      # Python ipaddress is_private for IPv4: the network AND its broadcast inside one of these.
      def private_ip: . as $i | any(("0.0.0.0/8", "10.0.0.0/8", "127.0.0.0/8", "169.254.0.0/16", "172.16.0.0/12",
        "192.0.0.0/29", "192.0.0.170/31", "192.0.2.0/24", "192.168.0.0/16", "198.18.0.0/15", "198.51.100.0/24",
        "203.0.113.0/24", "240.0.0.0/4", "255.255.255.255/32"); . as $r | $i | within($r | net));
      def private: net | (.base | private_ip) and (.base + pow(2; 32 - .len) - 1 | private_ip);
      # Python repr, so a message reads as it always did.
      def py: if type == "array" then "[" + (map(py) | join(", ")) + "]" elif type == "string" then "\u0027\(.)\u0027"
        elif . == null then "None" else tostring end;
      def pair: "(\(.[0] | py), \(.[1] | py))";
      def show: if . == null then "None" else tostring end;

      ($network | uci) as $net | ($firewall | uci) as $fw | ($dhcp | uci) as $dh
      | ($subnets | lines | map(split("\t") | {key: .[0], value: .[1]}) | from_entries) as $sub
      | ($base | if . == "" then 0 else tonumber end) as $base
      | ($sources | lines) as $sources | ($faiSubnets | lines) as $faiSubnets | ($faiHosts | lines) as $faiHosts
      | ($sshHosts | lines | unique) as $sshHosts
      | [$fw | sections("redirect")[] | select((.name // "") | startswith("Moonlight-"))] as $moon
      | [$sub.lanSubnet, $sub.vpnSubnet | select(. != null) | net] as $ranges

      # A stale mirror is reported ALONE: every other finding would be about the wrong file.
      | if ($net | has("network.lan.ipaddr") | not) then
          [["mirror", "\($mirror)/network.conf has no network.lan.ipaddr", "run `router-sync pull`: the mirror is missing or truncated"]]
        else [
          # The router own addresses live inside the subnets the repo declares.
          [(["lanSubnet", "network.lan.ipaddr"], ["vpnSubnet", "network.wg0.addresses"]) as [$opt, $key]
            | $sub[$opt] as $want | $net[$key] as $vals
            | if ($want | not) or ($vals | not) or ($vals | length == 0) then
                ["subnet", "could not read \($opt) or \($key)", "an anchor moved: fix this checker, do not delete the check"]
              elif ($vals[0] | split("/")[0] | ip | within($want | net)) | not then
                ["subnet", "\($key) is \($vals[0]), outside my.net.\($opt) (\($want))", "both describe the same network: align the router or the option"]
              else empty end],
          # SET EQUALITY both ways: the repo declares NO sources since 19/08/2026, so the router forwards NOTHING.
          (([$moon[] | .src_ip // ""] | unique) as $onRouter | ($sources | sort) as $inRepo
            | if $onRouter != $inRepo then
                [["moonlight", "router src_ip is \($onRouter | py), moonlightSources is \($inRepo | py)",
                  "the router forwards exactly what the repo declares: a redirect the repo does not know about is a port open to UFSCar, and one declared without the redirect is `Moonlight does not connect`"]]
              else [] end),
          # The ports are DERIVED from one base in the module; no source declared means none expected.
          ((if ($sources | length) == 0 then [] else [["tcp", "\($base - 5)"], ["tcp", "\($base)"], ["tcp", "\($base + 21)"], ["udp", "\($base + 9)-\($base + 11)"]] | unique end) as $want
            | ([$moon[] | [.proto // "", (.src_dport // "" | gsub(":"; "-"))]] | unique) as $got
            | if $got != $want then
                [["moonlight", "redirect ports are [\($got | map(pair) | join(", "))], basePort derives [\($want | map(pair) | join(", "))]",
                  "the offsets live in modules/nixos/services/sunshine.nix, and an EMPTY expectation means the direct path is retired, so the device should forward nothing"]]
              else [] end),
          [$moon[] | select((.src_dport // "") != (.dest_port // ""))
            | ["moonlight", "\(.name | show) maps \(.src_dport | show) to \(.dest_port | show)", "Sunshine derives every port from one base, so a translated port breaks the client"]],
          # A redirect that survives a DHCP change by pointing at the wrong host answers nothing.
          (([$moon[] | select(.dest_ip != $host) | .name // ""] | sort) as $bad
            | if ($bad | length) > 0 then
                [["moonlight", "these do not point at \($host): \($bad | py)", "the host address is the CSRF origin in modules/nixos/services/sunshine.nix"]]
              else [] end),
          # THEIR private ranges plus the tunnel-only hosts, never the public /25: docs/notes/network/network.md
          (if ($faiHosts | length) == 0 then
              [["fai", "could not read faiTunnelHosts", "an anchor moved: fix this checker, do not delete the check"]]
            else
              ([$faiSubnets[] | select(private)] + [$faiHosts[] | "\(.)/32"] | unique) as $want
              | ($net | named("fai_r") | to_entries | sort_by(.key)) as $routes
              | ([$routes[] | .value | select((.target // "") != "" and (.netmask // "") != "")
                  | (.netmask | prefix) as $p | ((.target | ip) / pow(2; 32 - $p) | floor) * pow(2; 32 - $p) | "\(dotted)/\($p)"] | unique) as $got
              | [$routes[] | select(.value.gateway != $host)
                  | ["fai", "\(.key) points at \(.value.gateway | show), not \($host)", "the gateway for the FAI ranges is this host, where nxBender runs"]]
              + (if $got != $want then
                  [["fai", "fai_r* routes \($got - $want | py) not declared, misses \($want - $got | py)", "modules/nixos/network/fai-gateway.nix holds faiSubnets and faiTunnelHosts"]]
                else [] end)
            end),
          # The exposed port is one number in two configs, and the repo owns it.
          (if [$fw | anon("redirect")[] | select(.dest_ip == $host and .dest_port == $sshPort)] | length == 0 then
              [["ssh", "no redirect sends \($sshPort) to \($host)", "services.openssh.ports in modules/nixos/network/network.nix owns that number"]]
            else [] end),
          # A split-DNS answer at an address no host claims only breaks by name. TWO mechanisms: an
          # `address=` override and a `config domain` record; reading only the first hid the t480.
          (([$host] + [$sshHosts[] | select(ip as $i | any($ranges[]; . as $r | $i | within($r)))]) as $known
            | [(($dh["dhcp.@dnsmasq[0].address"] // [])[] | [., (split("/") | last)]),
                ($dh | anon("domain")[] | ["domain \(.name // "?")", (.ip // "")])
              | select(.[1] as $a | ($a | ip) as $i | any($ranges[]; . as $r | $i | within($r)) and ($known | index([$a]) | not))
              | ["dns", "\(.[0]) answers \(.[1]), which no host in this repo declares", "declare the host or fix the entry: a wrong split-DNS only breaks by name"]]),
          # A host at a TUNNEL address needs a peer; ONE direction, since some peers have no ssh host.
          (if $sub.vpnSubnet then ($sub.vpnSubnet | net) as $vpn
              | ([$net | anon("wireguard_wg0")[] | .allowed_ips // "" | splits("\\s+") | select(length > 0) | split("/")[0]]) as $allowed
              | [$sshHosts[] | . as $h | select((ip | within($vpn)) and ($allowed | index([$h]) | not))
                  | ["peer", "ssh.nix reaches \(.), and no wg0 peer holds that address", "the peer left the router or never landed: the name resolves and nothing answers, which reads as `the machine is off`"]]
            else [] end),
          # Nothing is forwarded INTO the tunnel: a peer is off site, and a DNAT there has no gate.
          (if $sub.vpnSubnet then ($sub.vpnSubnet | net) as $vpn
              | [$fw | sections("redirect")[] | select(.dest_ip | ip | within($vpn))
                  | ["dnat", "\(.name // "?") forwards to \(.dest_ip), a tunnel address", "the tunnel is the only door for a peer: the T480\u0027s own repo states that rule for the machine that leaves the house, and this is where it is checked"]]
            else [] end)
        ] | add
        end
      | if length > 0 then
          "\nrouter-ssot: \(length) disagreement(s) between this repo and the router\n",
          (.[] | "  \(.[0]): \(.[1])\n    -> \(.[2])"),
          "\nThe mirror is READ-ONLY: fix the device with uci, then `router-sync pull`.",
          "FAIL"
        else "router-ssot: 9 checks, the mirror agrees with the repo" end
    ' >"$out" || exit 2
    if [[ "$(tail -n1 "$out")" == FAIL ]]; then
      head -n -1 "$out" >&2
      exit 1
    fi
    cat "$out"
  '';
}
