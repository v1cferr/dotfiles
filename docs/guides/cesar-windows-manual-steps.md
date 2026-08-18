# CESAR (my brother's Windows): the steps Nix cannot reach

The `cesar` host is declared in [`home/shell/ssh.nix`](../../home/shell/ssh.nix), but that
is **the client side only**. Everything that has to exist *inside* Windows (the authorized
key, the PATH, the packages) lives outside Nix's reach, because the machine is not NixOS and
is not mine. This guide exists so that it can be **redone in minutes** if Windows is
reinstalled or the account is recreated, instead of being rediscovered from scratch.

Same nature as the router's `authorized_keys` (OpenWrt), for the same reason: the repo
declares the client, the server is another system's territory.

## Fixed context

| what | value |
| --- | --- |
| Host / IP | `CESAR` / `192.168.1.40` (DHCP, see the trap at the end) |
| My account there | `v1cferr`, **a member of Administrators** |
| The owner's account | `drakk`, [never operate as them](../../home/shell/ssh.nix) |
| sshd | `OpenSSH_for_Windows_9.5`, on `22` (LAN) and `2223` (exposed on the WAN) |

**An admin's SSH session on Windows already comes with an ELEVATED token.** That is why
the commands below write to `C:\ProgramData` and to the machine PATH with no UAC, and also
why the Scoop installer refuses to install without `-RunAsAdmin`.

## 1. Key-based login

`ssh-copy-id` **does not work**: it assumes a POSIX shell, and the default shell of the
Windows sshd is `cmd.exe`. And because the account is an administrator, sshd **ignores** its
`~/.ssh/authorized_keys`, so only the machine file counts:

```powershell
Add-Content -Encoding ascii C:\ProgramData\ssh\administrators_authorized_keys '<id_ed25519.pub>'
icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r `
  /grant Administrators:F /grant SYSTEM:F
```

**There are two ways to get this wrong, and both are SILENT**: they fail by falling back
to the password, without telling the client anything:

- `Add-Content` without `-Encoding ascii` writes UTF-16, which sshd does not read;
- without the `icacls`, the file stays writable by more people and sshd **refuses** it.

Validate unambiguously (`BatchMode` forbids the password prompt, so it only passes if the key
did it):

```bash
ssh -o BatchMode=yes v1cferr@192.168.1.40 "echo OK"
```

## 2. GNU coreutils for the whole machine

Git for Windows already bundles the GNU userland (coreutils 8.32, grep, sed, awk, less, vim)
in `C:\Program Files\Git\usr\bin`, so **nothing needs installing**, only exposing.

```powershell
$d = "C:\Program Files\Git\usr\bin"
$p = [Environment]::GetEnvironmentVariable("PATH","Machine")
if ($p -split ";" -notcontains $d) {
  [Environment]::SetEnvironmentVariable("PATH", $p.TrimEnd(";") + ";" + $d, "Machine")
}
```

**APPEND AT THE END, never at the front**, and that order is the whole decision. That
directory brings `find.exe`, `sort.exe`, `tar.exe`, `link.exe` and `echo.exe`, which have
Windows namesakes with **completely different** semantics. Prepending breaks `.bat` scripts
and MSVC builds (the MSYS `link.exe` is not Microsoft's linker). At the end, you gain
everything that does not conflict and lose nothing. Check with `where`:

```text
where find  → C:\Windows\System32\find.exe          (Windows wins, correct)
              C:\Program Files\Git\usr\bin\find.exe
where ls    → C:\Program Files\Git\usr\bin\ls.exe   (only the GNU one exists)
```

**In PowerShell this pays off less than it looks**: `ls`, `cat`, `cp`, `rm`, `sort`,
`curl` and `echo` are native ALIASES, and an alias always beats the PATH. There you have to
type `ls.exe`. In `cmd` there are no aliases, so it works directly, and inside bash the
question does not even come up.

Undoing it means removing that entry from the machine PATH. Nothing else is touched.

## 3. Scoop (per user) and modern tooling

```cmd
cd /d %USERPROFILE%
powershell -ExecutionPolicy Bypass -Command "irm get.scoop.sh -outfile scoop-install.ps1; .\scoop-install.ps1 -RunAsAdmin; del scoop-install.ps1"
scoop install ripgrep fd jq
```

The `-ExecutionPolicy Bypass` applies to that process only, it does not change the machine
policy. The `-RunAsAdmin` is mandatory because of the SSH session's elevated token (see the
context above). It installs into `%USERPROFILE%\scoop`, which means it **leaves along with
the profile**.

## 4. Claude Code (its own profile)

```cmd
cd /d %USERPROFILE%
curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
```

No Node, no admin, and it installs into `%USERPROFILE%\.local\bin\claude.exe`. The installer
does **not** put that on the PATH; do it by hand, on the `User` branch:

```powershell
[Environment]::SetEnvironmentVariable('PATH',
  [Environment]::GetEnvironmentVariable('PATH','User') + ';C:\Users\v1cferr\.local\bin', 'User')
```

**Do NOT use `setx PATH "%PATH%;..."`**, which is the advice you find everywhere:
`%PATH%` expands to the **combined** PATH (machine + user) and `setx` writes all of it into
the user branch, duplicating the machine PATH inside yours, on top of **truncating at 1024
characters**, eating the rest with no warning.

Run both blocks **outside** `C:\Users\drakk\dev\...`: they write a temporary file into the
current directory, and dirtying the `git status` of the owner's repo is a trace that should
not exist.

## 5. Access from outside the house (his phone)

He asked for exactly what I have: one `ssh` command from the phone, from anywhere,
typing a password. **The command is the same at home and on mobile data**, which
is the whole point of the split-DNS entry below:

```sh
ssh drakk@cesar-ssh.v1cferr.dev -p 2223
```

Five legs, and only the last three needed any work:

| leg | where it lives |
| --- | --- |
| the name resolving from outside | already done: the `*.v1cferr.dev` wildcard CNAME points at the zone's anchor |
| the anchor tracking the public IP | already done: `services.cloudflare-dyndns` in [`system/net/network.nix`](../../system/net/network.nix) |
| WAN `2223` reaching `192.168.1.40` | `firewall.ssh_cesar`, mirrored in [`router/uci/firewall.conf`](../../router/uci/firewall.conf) |
| the name working INSIDE the house | `dhcp.@dnsmasq[0].address`, in [`router/uci/dhcp.conf`](../../router/uci/dhcp.conf) |
| Windows answering on `2223` | the three steps below |

**`2222` was not available**: it is already forwarded to `192.168.1.10`, my
machine. One public IP means one port per host.

**The port REPEATS on both sides (`2223` to `2223`, not `2223` to `22`)**, and
that is what buys the single command. Inside the house the router answers
`192.168.1.40` for this name, so the packet never crosses the NAT and has to find
the same port number there that it would find from outside. Forwarding `2223` to
`22` would leave him two commands to remember, one per network, which is the
failure mode this setup exists to avoid.

The split-DNS entry works by dnsmasq's LONGEST MATCH: the zone already had
`address=/v1cferr.dev/192.168.1.10`, a wildcard that was answering for this name
too, and `/cesar-ssh.v1cferr.dev/192.168.1.40` is more specific, so it wins
without touching the other subdomains.

### The three Windows steps

**1. Listen on both ports.** `Port` goes at the TOP of `sshd_config`, before any
`Match`, because every keyword after a `Match` belongs to that block and this file
ends in `Match Group administrators`:

```text
Port 22
Port 2223
```

The `22` is not decoration: the shipped file carries only `#Port 22`, commented,
so declaring `2223` alone MOVES the listener instead of adding one, and `ssh cesar`
on the LAN stops working.

**2. Open the Windows firewall**, whose shipped rule covers `22` only:

```powershell
New-NetFirewallRule -Name OpenSSH-Server-In-TCP-2223 `
  -DisplayName "OpenSSH SSH Server (sshd) 2223" -Enabled True `
  -Direction Inbound -Protocol TCP -Action Allow -LocalPort 2223 -Profile Private
```

`-Profile Private` and not `Public`: the DNAT'd packet still arrives on the
Ethernet NIC, and that NIC sits in the `Private` profile. The profile is a
property of the interface, never of the packet's source address.

**3. Restrict the exposed port to the accounts that exist**, at the end of the file:

```text
Match LocalPort 2223
    AllowUsers drakk v1cferr
```

Bots sweeping for `root`, `admin`, `test` and `ubuntu` are then refused before
they reach an account that can be locked out. It is the cheapest line in this guide.

Then `Restart-Service sshd -Force`, which the current SSH session survives
(measured 18/08/2026): each connection is its own process.

### Validating without locking yourself out

`sshd -T`, the usual "print the effective config", **prints nothing** on
Win32-OpenSSH 9.5 through an SSH session. `sshd -t` does work, but only through
the exit code:

```bat
C:\Windows\System32\OpenSSH\sshd.exe -t & if errorlevel 1 (echo FAIL) else (echo OK)
```

Run it BEFORE restarting the service. A broken `sshd_config` on a machine whose
only access is that same sshd is a walk to the other room, or worse if it happens
from outside the house.

### What replaces fail2ban, because Windows has none

`drakk` is an Administrator and the port accepts passwords, so the exposure is
real. What actually brakes a brute force here:

- **Windows' own account lockout does the heavy lifting**, and it was already on
  by default: 10 failures lock the account for 10 minutes (`net accounts`). That
  caps an attacker at roughly 60 guesses an hour, which is not a brute force.
- **The `limit` on the port forward is a second brake, not a ban.**
  `limit='30/minute'` with `limit_burst='20'` renders as
  `limit rate 30/minute burst 20 packets` inside the DNAT rule. Two honest
  limitations: it is GLOBAL and not per source address, so a flood can eat the
  budget a legitimate connection needs, and it drops packets rather than
  remembering the offender. It was sized generously for that reason, since a human
  opening one session never comes close to 30 a minute.
- **The lockout's price is a denial of service**, and that is the accepted trade:
  somebody hammering `drakk` from the internet keeps him locked out in 10 minute
  windows. The failed attempts are Event ID `4625` in the Security log.

Proving it from outside, without leaving the house, is the same trick the
[network notes](../notes/network/network.md) use for `2222`:

```sh
curl -s -H 'Accept: application/json' \
  'https://check-host.net/check-tcp?host=<public-ip>%3A2223&max_nodes=3'
curl -s -H 'Accept: application/json' 'https://check-host.net/check-result/<request_id>'
```

Two of the three nodes connecting is a pass (18/08/2026: Israel 0.28s, USA 0.17s,
Iran timed out, which is Iran's filtering and not ours).

## Traps that outlive this guide

- **The IP is DHCP.** If the address changes, the alias breaks. The fix is a DHCP
  reservation on OpenWrt, not one more `my.*` option in the repo.
- **The post-quantum warning on every connection is not our config**: the server is OpenSSH
  9.5 and `mlkem768x25519` only exists from 9.9 on. It goes away when Microsoft updates
  Win32-OpenSSH. Deliberately **not** silenced with `WarnWeakCrypto`.
- **Stdin does not reach PowerShell through that sshd.** `powershell -Command -`
  reads nothing, because the default shell is `cmd.exe` and the session's stdin is
  not a console. Multi-line work goes inline through `-Command "..."`, or gets
  copied over first and run with `-File`.
- **`where bash` lies over there.** The only `bash` on the PATH is
  `C:\Windows\System32\bash.exe`, which is the legacy WSL stub (with no distro installed).
  The real bash is `C:\Program Files\Git\bin\bash.exe`, and it does not show up because only
  `Git\cmd` is on the PATH.
