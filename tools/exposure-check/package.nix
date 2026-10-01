# exposure-check: the house seen from OUTSIDE, run by the canary from a GitHub runner. The open TCP
# ports against the router's declared forwards, plus ssh-audit: docs/notes/network/exposure.md
{
  writers,
  nmap,
  ssh-audit,
  openssh,
  host,
  sshPort,
  mirror,
}:

writers.writePython3Bin "exposure-check"
  {
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  }
  ''
    """Scan the public anchor and fail on any port the router's mirror does not forward."""
    import json
    import os
    import re
    import socket
    import subprocess
    import sys
    import time

    HOST = "${host}"
    FIREWALL = "${mirror}/firewall.conf"
    SSH_PORT = ${toString sshPort}
    # What this machine's sshd must offer and nothing more: a key, or password plus TOTP in PAM. A
    # bare `password` would mean the TOTP got bypassed (docs/notes/network/network.md).
    SSH_METHODS = {"publickey", "keyboard-interactive"}


    def declared():
        """Every WAN port the mirror opens over TCP: the DNAT forwards and the router's own accepts."""
        sections, kinds = {}, {}
        for line in open(FIREWALL):
            m = re.match(r"firewall\.([^.=]+)=(\w+)$", line.strip())
            if m:
                kinds[m[1]] = m[2]
                continue
            m = re.match(r"firewall\.([^.=]+)\.(\w+)=(.*)$", line.strip())
            if m:
                sections.setdefault(m[1], {})[m[2]] = re.findall(r"'([^']*)'", m[3])
        ports = {}
        for name, opts in sections.items():
            if opts.get("src") != ["wan"] or "tcp" not in " ".join(opts.get("proto", ["tcp udp"])):
                continue
            key = {"redirect": "src_dport", "rule": "dest_port"}.get(kinds.get(name))
            if key and key in opts and opts.get("target", ["DNAT" if key == "src_dport" else ""])[0] in ("DNAT", "ACCEPT"):
                for port in opts[key]:
                    ports[int(port)] = (opts.get("name") or [name])[0]
        return ports


    def scanned():
        """Every TCP port, from outside. Filtered ones are silence, so only `open` is reported."""
        out = subprocess.run(
            ["${nmap}/bin/nmap", "-Pn", "-p-", "-T4", "--max-retries", "1", "--min-rate", "1000", "--open", "-oG", "-", HOST],
            check=True, text=True, capture_output=True).stdout
        return {int(p) for p in re.findall(r"(\d+)/open/tcp", out)}


    def banner(port):
        try:
            with socket.create_connection((HOST, port), timeout=5) as s:
                return s.recv(64).decode(errors="replace")
        except OSError:
            return ""


    def methods(port):
        """What sshd offers to a login with no credential; one retry past the 20s penalty floor."""
        for attempt in (1, 2):
            probe = subprocess.run(
                ["${openssh}/bin/ssh", "-o", "BatchMode=yes", "-o", "PreferredAuthentications=none",
                 "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=10",
                 "-p", str(port), f"v1cferr@{HOST}", "true"], text=True, capture_output=True).stderr
            m = re.search(r"Permission denied \(([^)]*)\)", probe)
            if m:
                return set(m[1].split(",")), ""
            if attempt == 1:
                time.sleep(30)
        return set(), probe.strip().splitlines()[-1] if probe.strip() else "no answer"


    def audit(port):
        """The methods FIRST (the only thing judged), then ssh-audit, whose bare disconnect penalises."""
        offered, why = methods(port)
        res = subprocess.run(["${ssh-audit}/bin/ssh-audit", "-j", "-p", str(port), HOST], text=True, capture_output=True)
        data = json.loads(res.stdout or "{}")
        return data.get("banner", {}).get("software", "?"), res.returncode, data.get("recommendations") or {}, offered, why


    def main():
        expected, found = declared(), scanned()
        errors, warnings, rows = [], [], []
        for port in sorted(found | set(expected)):
            state = "open" if port in found else "closed"
            if port in found and port not in expected:
                errors.append(f"port {port} is open to the internet and the router's mirror forwards nothing there")
            if port not in found:
                warnings.append(f"{expected[port]} ({port}) is forwarded but did not answer: is the machine up?")
            rows.append(f"| {port} | {expected.get(port, '**not declared**')} | {state} | |")
            if port in found and banner(port).startswith("SSH-"):
                software, code, recs, offered, why = audit(port)
                verdict = "clean" if code == 0 and not recs else f"exit {code}, {json.dumps(recs)}"
                rows[-1] = f"| {port} | {expected.get(port, '**not declared**')} | open | {software}, {verdict}, auth: {','.join(sorted(offered)) or why} |"
                # Only THIS machine's sshd is judged; another one (2223 is my brother's Windows) warns.
                mine = errors if port == SSH_PORT else warnings
                if code != 0 or recs:
                    mine.append(f"ssh-audit on {port}: {verdict}")
                if port == SSH_PORT and offered != SSH_METHODS:
                    errors.append(f"{port} offers {sorted(offered)} ({why or 'answered'}), expected {sorted(SSH_METHODS)}")

        table = "\n".join([f"### {HOST} from outside", "", "| Port | Declared as | State | SSH |",
                           "| --- | --- | --- | --- |", *rows, ""])
        print(table)
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as fh:
                fh.write(table + "\n")
        for w in warnings:
            print(f"::warning::{w}" if os.environ.get("GITHUB_ACTIONS") else f"warning: {w}")
        for e in errors:
            print(f"::error::{e}" if os.environ.get("GITHUB_ACTIONS") else f"error: {e}")
        return 1 if errors else 0


    sys.exit(main())
  ''
