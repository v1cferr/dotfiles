# ssh

Module: [`home/shell/ssh.nix`](../../../home/shell/ssh.nix)

The client config. Five hosts, and almost every line in there is a trap somebody else's server
handed us.

The private key is state and a secret, so it comes from the backup, not from Nix (rule 6).

## `faiResilience` is sized to VS Code's budget, not to comfort

The FAI tunnel drops routes transiently with `ppp0` still alive, so a long session needs to
tolerate the hole instead of dying. But EVERYTHING is sized to fit inside VS Code Remote-SSH's
budget, which aborts with `Connecting with SSH timed out` at a FIXED 17 s (from the extension's
log: `Using connect timeout of 17 seconds`).

| Setting | Value | Why that number |
| --- | --- | --- |
| `ConnectTimeout` plus `ConnectionAttempts` | 7 x 2 = 14 s | worst case INSIDE the 17 s. It was 15 x 3 = 45 s, and VS Code gave up mid second attempt and reported a timeout with the host about to answer |
| `ServerAliveInterval` | 15 s | an encrypted keepalive holds the idle session on the SonicWall |
| `ServerAliveCountMax` | 8 (~2 min) | it was 20 (~5 min) and that was COUNTERPRODUCTIVE |
| `ControlPersist` | 10m | reopening becomes instant |

**Why 8 and not 20.** With 5 min of tolerance the multiplexed master stayed stuck in a dead tunnel
that whole time, and every new connection glued itself to it and hung along
(`mux_client_request_session: Broken pipe` in the VS Code log). 2 min still rides out a blip; a
real drop dies fast and the extension reconnects.

`TCPKeepAlive = no` because the kernel's keepalive drops before the deadline above, so SSH's is the
one in charge.

A master stuck in a tunnel that died: `ssh -O exit workstation` kills the socket immediately.

## The router is Dropbear, and a reflash regenerates its host key

`ssh router` reaches OpenWrt 25.12 / BusyBox. It accepts ed25519, but a firmware update
REGENERATES the host key and the next connection aborts with
`REMOTE HOST IDENTIFICATION HAS CHANGED`. That is the flash, not an attack:
`ssh-keygen -R 192.168.1.1` and accept again.

`authorized_keys` lives ON THE ROUTER, out of Nix's reach, so installing the key is a manual step,
once per reflash: `ssh-copy-id -i ~/.ssh/id_ed25519.pub v1cferr@192.168.1.1`. It survives a
`sysupgrade` with "keep settings"; a clean reflash requires repeating it.

No `faiResilience` here: that sizes keepalive and multiplexing for the SonicWall tunnel and for a
17s budget, and this is a LAN hop with <1ms. Inheriting it would be cargo cult.

The IP is a literal because it is the ONLY place in the repo naming the gateway (Caddy uses the
/24 range, not the .1), and a lone literal does not trigger rule 11.

## The mother's T480 is the second Windows, and it repeats almost none of the traps

`ssh t480` reaches a ThinkPad T480 (Windows 11 IoT Enterprise LTSC 24H2) being prepared for my
mother. Everything below was measured on 22/08/2026, from this side, and the interesting part is
how little of the `cesar` section applies.

**The address is the TUNNEL address, and that is not a shortcut.** `10.10.10.6` is the WireGuard
peer, and over there `sshd_config` carries `ListenAddress 10.10.10.6`, so there is no path to that
sshd from the LAN even while the machine is still in the house. It is NOT a literal here any more:
the RDP wrapper became a second consumer, so the value moved into `my.t480`
([`home/net/t480.nix`](../../../home/net/t480.nix)) and this block reads it, which is rule 11. It is the machine's own rule: no
port of that host is exposed, and SSH, Sunshine and RDP accept the tunnel and the home LAN only.

**That bind is why sshd there DEPENDS on the tunnel**, and it is the sharpest thing this host has to
teach. `sc qc sshd` gives `WireGuardTunnel$mae-t480`, because an address that does not exist yet
cannot be bound and a Win32 service that fails to bind does not retry. The dependency is not the
whole answer either: Windows guarantees the ORDER at boot, and when a dependency RESTARTS the
dependent is stopped and NOT brought back. What covers that is a watchdog on the machine itself, and
knowing this is what keeps "SSH died" from being investigated on this side.

**No `RemoteCommand`, and no `-cmd` twin.** `HKLM\SOFTWARE\OpenSSH\DefaultShell` over there is
already `C:\Program Files\Git\bin\bash.exe` WITH `DefaultShellCommandOption = -c`, so an
interactive session and `ssh t480 <command>` both work with nothing on the client. The `cesar` pair
exists because that machine's shell is PowerShell, which needs the `&`, not because Windows demands
it.

**No `SetEnv TERM`**, for the same reason as cesar: that sshd ships no `AcceptEnv`, so the variable
dies on the server whatever the client sends.

**No keepalive block, and NOT because the path is short.** The server sends them
(`ClientAliveInterval 30`, `ClientAliveCountMax 4`), so a client-side copy would be a second
mechanism doing one job. That answers the temptation `faiResilience` creates every time a host is
added over a link that is not a LAN hop.

**The admin key trap applies, and the `icacls` half of it was a NO-OP here.** `v1cferr` is an
administrator there, so sshd reads only `C:\ProgramData\ssh\administrators_authorized_keys`, the
same as cesar. But the file inherited exactly `BUILTIN\Administrators:(F)` and `SYSTEM:(F)` from
that directory, which is precisely what sshd demands, so the permissions step had nothing to fix.
What DID fail was running the cesar guide's `icacls` line inside Git Bash: MSYS rewrites
`/inheritance:r` into a path, and on a pt-BR Windows the local groups are not named `Administrators`
and `SYSTEM`. If it ever has to run there: `MSYS_NO_PATHCONV=1` plus the SIDs, `*S-1-5-32-544` and
`*S-1-5-18`.

**Appending the key from bash removes the UTF-16 trap by construction.** `>>` in bash writes LF and
ASCII, which is the encoding sshd wants, so the `-Encoding ascii` that PowerShell's `Add-Content`
needs has no counterpart to get wrong.

**The Windows side is deliberately NOT documented in this repo.** That machine carries a repo of its
own (`~/dotfiles` on the T480: numbered idempotent scripts, an inventory, a `winget configure` DSC
file), so a guide here would be a second owner for one procedure, which is rule 14, and the copy
that is not applied is the one that drifts, which is rule 16. The `cesar` guide exists because that
machine has no repo. What belongs here is only the CONTRACT between the two: the peer address, the
name the router answers, and the fact that nothing is forwarded to it.

## The brother's PC is Windows 11, and that is where all the traps come from

`ssh cesar` reaches OpenSSH_for_Windows 9.5. This declares only the CLIENT side; the Windows-side
steps live in [`../guides/cesar-windows-manual-steps.md`](../../guides/cesar-windows-manual-steps.md)
so they can be redone in minutes if that Windows gets reinstalled.

**No `SetEnv TERM`.** That sshd does not ship `AcceptEnv`, so the variable is discarded on the
server no matter what the client sends. The reason used to be doubled up (the default shell was
`cmd.exe`, which does not read TERM), and that half expired with the shell swap below; the
`AcceptEnv` half is the one that was load-bearing.

**The post-quantum warning is honest noise.** `connection is not using a post-quantum key exchange`
shows up on EVERY connection and is not our misconfiguration: `mlkem768x25519` only exists from
OpenSSH 9.9 onward, and Windows 11 (build 26200) still ships 9.5. It could be silenced with
`WarnWeakCrypto = "no"` (which exists in our 10.4), and that is precisely why it is NOT set:
silencing it per host hides the server's real lag, and the day it gets fixed would go unnoticed.

**The authorized_keys file is not the one you expect.** Measured on 10/08: the `v1cferr` over there
is an ADMINISTRATOR (`whoami /groups` brings BUILTIN\Administrators, SID S-1-5-32-544), and that
decides the file. For a member of that group the Windows sshd IGNORES `~/.ssh/authorized_keys` and
reads only:

```powershell
Add-Content C:\ProgramData\ssh\administrators_authorized_keys '<id_ed25519.pub>'
icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r `
  /grant "Administrators:F" /grant "SYSTEM:F"
```

The `icacls` is not decoration: the sshd REFUSES the file, and falls back to the password silently
on the client side, if anybody else can write to it. And `ssh-copy-id` does NOT work here, because
it assumes a POSIX shell on the other end.

**The RemoteCommand swaps the login shell for Git Bash.** `where git` gives
`C:\Program Files\Git\cmd\git.exe`, but `where bash` does NOT find that bash, because only
`Git\cmd` is on the PATH while `bash.exe` lives in `Git\bin`, hence the absolute path. The only
`bash` on the PATH is `C:\Windows\System32\bash.exe`, which is NOT bash: it is the legacy WSL stub,
and the machine has no distro installed.

**The registry shell swap was refused once, and then the owner asked for it** (18/08/2026).
`HKLM:\SOFTWARE\OpenSSH\DefaultShell` is now
`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`, because he drives Claude Code from
PowerShell and wanted his SSH session to land there. The old refusal is not being retracted as
wrong: its reason was that a GLOBAL setting would impose a shell on the OWNER, and it is the owner
who reversed the premise. Win32-OpenSSH has no per-user shell, and the per-user alternative
(`Match User` plus `ForceCommand`) applies to subsystems as well, so it would have cost him scp,
sftp and Remote-SSH.

**`DefaultShellCommandOption` has to be set along with it**, and forgetting it is the worst kind of
half-broken: sshd hands a one-off command to the shell with `/c`, which is cmd's switch and which
PowerShell rejects, so interactive sessions keep working while EVERY non-interactive one dies. The
second value is `-c`, and it is what keeps `ssh cesar-cmd <command>` alive.

**That swap is also why `RemoteCommand` carries a `&`.** In PowerShell a quoted path at the start
of a line is a STRING, not a command, so the old `"C:\Program Files\Git\bin\bash.exe" -l -i`
stopped launching bash and started returning a parse error. The `&` call operator runs it. Both
forms measured on 18/08/2026.

**Why `cesar-cmd` exists, and it is not duplication.** `RemoteCommand` and a command line are
MUTUALLY EXCLUSIVE in ssh (`Cannot execute command-line and remote command`), so with the
`RemoteCommand` block, `ssh cesar <cmd>`, `scp` and `rsync` STOP WORKING. The twin is the
declarative way out: `cesar` to sit down and work, `cesar-cmd` to copy a file or run a one-off.
The alternative was memorizing `-o RemoteCommand=none` on every invocation, which is exactly what
the repo exists so you do not have to remember.

The IP stopped being a literal per block and became a `let` binding, `cesarHost`, the day the third
block appeared (rule 11 applied INSIDE the module: no `my.*` option, because nothing outside this
file reads it). It comes from DHCP: if the router hands out another address the alias breaks, and
the fix is the reservation on the OpenWrt (`dhcp.arch_cesar`), not one more option.

## That machine DUAL BOOTS, and known_hosts keys by name and not by address

`ssh v1cferr@192.168.1.40` died with `REMOTE HOST IDENTIFICATION HAS CHANGED` on 25/08/2026, and it
was not an attack: the machine had booted into Linux. Two operating systems, each with its OWN sshd
and its own host keys (`C:\ProgramData\ssh\ssh_host_*` on Windows, `/etc/ssh/ssh_host_*` on the
Linux side), answering on the SAME address and port. Measured that day, none of the three keys
matched:

| | Windows (OpenSSH 9.5) | Linux (OpenSSH 10.5) |
| --- | --- | --- |
| ed25519 | `SHA256:PfytwEuINkNhyNE5RMzea0NkL4O1AFWuoeOhCI5CWdE` | `SHA256:ovue+UzduT+luQHHLT3KUfOwVbbGMA949wdQJPBdUmQ` |
| rsa | `SHA256:GNgSXh/w+P8nbk/eQ373Bd3DlPSQlTwj38ShskQF3Dg` | `SHA256:KWrwbOOK0X4OD/2W0SNpxYO2fR6FjbwCUBqFnEJ7RLQ` |
| ecdsa | `SHA256:MOzk0McYirsptnTn2Y4tRL8ucV4yfEDRNGmlRInuxqQ` | `SHA256:HyD7k1eBqJwpKEYqnaPiCNf/7Bi38SwgnQdHw9a51yo` |

**The alarm is CORRECT and cannot be tuned away.** `known_hosts` maps a NAME (a host, an IP) to a
key, so one address with two identities is, to the client, indistinguishable from somebody having
taken over the address. `ssh-keygen -R 192.168.1.40` "fixes" it for the OS booted right now and
breaks the next reboot, forever, which is how a real hijack ends up looking like routine.

**`HostKeyAlias` is the fix, and it is one word per block.** It changes ONLY the name used to look
the host key up, never the address dialed, so the three blocks keep `cesarHost` and split into two
identities: `cesar` and `cesar-cmd` verify under `cesar-windows`, `cesar-linux` under `cesar-linux`.
Both sets coexist in `known_hosts` and neither boot touches the other's line.

**The price is that the raw IP is now off limits.** `ssh v1cferr@192.168.1.40` carries no alias, so
it keeps flapping between the two keys: the alias IS the interface. Same hole on the external path,
`cesar-ssh.v1cferr.dev:2223`, whose entry here still holds the Windows key only, and whose real
client is the phone, out of this config's reach.

**Asking for the wrong OS now raises the SAME warning, and that is the design.** With Linux up,
`ssh cesar` aborts with `REMOTE HOST IDENTIFICATION HAS CHANGED` on the `cesar-windows` line, and
that reading is exact: the alias is a statement about WHICH identity is expected, so a mismatch is a
refusal to talk to the other one. Verified in both directions on 25/08/2026: `cesar-linux` connected
against the live keys (it only stopped at the password prompt), `cesar-windows` refused.

**`known_hosts` is state, so the split was done by hand** (25/08/2026): the Windows trio, already
trusted, was relabeled from `192.168.1.40` to `cesar-windows`, and the Linux trio was seeded from
`ssh-keyscan` piped through `sed`. That seed is trust-on-first-use on the LAN, NOT verification: the
ed25519 above still has to be compared against `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`
read on that machine. Backup at `~/.ssh/known_hosts.bak-20260825`.

**`cesar-linux` does not authenticate yet**, and this side cannot tell why. It answers
`Permission denied (publickey,password)`, which is what sshd says both for a key that is not in
`authorized_keys` and for a user that does not exist, because OpenSSH refuses to enumerate users.
Closing it takes one command over there, and `ssh-copy-id` DOES work on this half (the Windows
`administrators_authorized_keys` detour above is Win32-OpenSSH's, not Linux's).
