# ssh

Module: [`home/shell/ssh.nix`](../../home/shell/ssh.nix)

The client config. Four hosts, and almost every line in there is a trap somebody else's server
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

## The brother's PC is Windows 11, and that is where all the traps come from

`ssh cesar` reaches OpenSSH_for_Windows 9.5. This declares only the CLIENT side; the Windows-side
steps live in [`../guides/cesar-windows-manual-steps.md`](../guides/cesar-windows-manual-steps.md)
so they can be redone in minutes if that Windows gets reinstalled.

**No `SetEnv TERM`.** The default shell of the Windows sshd is `cmd.exe`, which does not read TERM,
and that sshd does not ship `AcceptEnv`, so the variable would be discarded on the server anyway.

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

**The RemoteCommand swaps cmd.exe for Git Bash.** `where git` gives
`C:\Program Files\Git\cmd\git.exe`, but `where bash` does NOT find that bash, because only
`Git\cmd` is on the PATH while `bash.exe` lives in `Git\bin`, hence the absolute path. The only
`bash` on the PATH is `C:\Windows\System32\bash.exe`, which is NOT bash: it is the legacy WSL stub,
and the machine has no distro installed.

Swapping the shell through the registry (`HKLM:\SOFTWARE\OpenSSH\DefaultShell`) was REFUSED: it is
global and would change the shell of EVERY SSH session on that machine, the owner's included. On
the client side the choice is ours alone and it goes away with this file.

**Why `cesar-cmd` exists, and it is not duplication.** `RemoteCommand` and a command line are
MUTUALLY EXCLUSIVE in ssh (`Cannot execute command-line and remote command`), so with the
`RemoteCommand` block, `ssh cesar <cmd>`, `scp` and `rsync` STOP WORKING. The twin is the
declarative way out: `cesar` to sit down and work, `cesar-cmd` to copy a file or run a one-off.
The alternative was memorizing `-o RemoteCommand=none` on every invocation, which is exactly what
the repo exists so you do not have to remember.

The IP is literal and comes from DHCP: if the router hands out another address the alias breaks,
and the fix is a DHCP reservation on the OpenWrt, not one more `my.*` option.
