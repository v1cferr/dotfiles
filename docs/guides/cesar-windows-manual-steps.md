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
| sshd | `OpenSSH_for_Windows_9.5` |

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

## Traps that outlive this guide

- **The IP is DHCP.** If the address changes, the alias breaks. The fix is a DHCP
  reservation on OpenWrt, not one more `my.*` option in the repo.
- **The post-quantum warning on every connection is not our config**: the server is OpenSSH
  9.5 and `mlkem768x25519` only exists from 9.9 on. It goes away when Microsoft updates
  Win32-OpenSSH. Deliberately **not** silenced with `WarnWeakCrypto`.
- **`where bash` lies over there.** The only `bash` on the PATH is
  `C:\Windows\System32\bash.exe`, which is the legacy WSL stub (with no distro installed).
  The real bash is `C:\Program Files\Git\bin\bash.exe`, and it does not show up because only
  `Git\cmd` is on the PATH.
