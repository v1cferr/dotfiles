# The client SSH config (a declarative ~/.ssh/config): the FAI hosts through the split-tunnel
# VPN. The private key (~/.ssh/id_ed25519) is STATE/a secret, so it comes from the backup, not
# from Nix (rule 6).
{ config, ... }:

let
  ws = config.my.fai.workstation; # SSOT: home/net/fai-workstation.nix (rule 11)

  # Resilience for long sessions over the SonicWall tunnel (a transient routing hole with ppp0
  # still alive). Tolerating the hole instead of dropping the session, but EVERYTHING sized to
  # fit inside VS Code Remote-SSH's budget, which aborts with "Connecting with SSH timed out" at
  # a FIXED 17 s (from the extension's log: "Using connect timeout of 17 seconds").
  faiResilience = {
    ServerAliveInterval = 15; # an encrypted keepalive every 15s: it holds the idle session on the SonicWall
    # 8 failures (~2 min) of tolerance. It was 20 (~5 min) and that was COUNTERPRODUCTIVE: the
    # multiplexed master stayed stuck in a dead tunnel for all that time, and every new
    # connection glued itself to it and hung along ("mux_client_request_session: Broken pipe" in
    # the VS Code log). 2 min still rides out a blip; a real drop dies fast and the extension
    # reconnects.
    ServerAliveCountMax = 8;
    TCPKeepAlive = "no"; # the kernel's keepalive drops before the deadline above; SSH's is in charge
    ControlMaster = "auto"; # Remote-SSH opens several connections, so multiplex them all onto one TCP
    ControlPath = "~/.ssh/cm-%r@%h:%p"; # the master's socket (per user/host/port)
    ControlPersist = "10m"; # the master survives 10 min past the last channel: reopening becomes instant
    # 7x2 = 14 s worst case, INSIDE Remote-SSH's 17 s. It used to be 15x3 = 45 s: VS Code gave up
    # in the middle of the 2nd attempt and reported a timeout even with the host about to answer.
    ConnectTimeout = 7;
    ConnectionAttempts = 2; # a freshly raised VPN usually refuses the 1st attempt
  };
  # A master stuck in a tunnel that died? `ssh -O exit workstation` kills the socket right away.
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false; # the "*" block with old defaults was deprecated; OpenSSH already ships sane ones

    # Both live in the 200.136.209.128/25 subnet, routed by `vpn connect fai`.
    settings = {
      # The FAI workstation (the same machine as `wake-workstation`; host/MAC come from the SSOT).
      workstation = faiResilience // {
        HostName = ws.host;
        User = ws.user;
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
        SetEnv = {
          TERM = "xterm-256color";
        }; # the right colors on the remote terminal
      };
      # The home router (OpenWrt 25.12 / BusyBox). `ssh router`.
      #
      # NO `faiResilience`: that sizes keepalive and multiplexing for the SonicWall tunnel and
      # for Remote-SSH's 17s budget. This is a LAN hop with <1ms, and inheriting that would be
      # cargo cult, not configuration.
      #
      # A literal IP and not a `my.*` option: it is the ONLY place in the repo that names the
      # gateway's address (Caddy uses the /24 range, not the .1). A lone literal does not trigger
      # rule 11, the same justification domain.nix records.
      #
      # WARNING: the server is DROPBEAR, not OpenSSH. It accepts ed25519, but a firmware update
      # REGENERATES the host key and the next `ssh router` aborts with "REMOTE HOST
      # IDENTIFICATION HAS CHANGED". Then it is `ssh-keygen -R 192.168.1.1` and accepting again;
      # it is not an attack, it is the flash.
      #
      # WARNING: authorized_keys LIVES ON THE ROUTER, out of Nix's reach (OpenWrt is not NixOS).
      # This declares only the CLIENT SIDE. Installing the key is a manual step, once per
      # reflash:
      #   ssh-copy-id -i ~/.ssh/id_ed25519.pub v1cferr@192.168.1.1
      # It survives a `sysupgrade` with "keep settings"; a clean reflash requires repeating it.
      router = {
        HostName = "192.168.1.1";
        User = "v1cferr";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      # My brother's PC, on the home LAN (`ssh cesar`, CESAR being the machine's hostname).
      #
      # This declares ONLY the client side. The Windows-side steps (the authorized key,
      # coreutils on the machine PATH, Scoop, Claude Code) are not reachable by Nix and live in
      # docs/guides/cesar-windows-manual-steps.md, so they can be redone in minutes if that
      # Windows gets reinstalled.
      #
      # It is WINDOWS 11 with OpenSSH_for_Windows_9.5, and that is where all the traps come from:
      #
      # WARNING: no `SetEnv TERM`. The default shell of the Windows sshd is **cmd.exe**, which
      # does not read TERM, and that sshd does not ship `AcceptEnv`, so the variable would be
      # discarded on the server anyway. Sending it regardless would be cargo cult.
      #
      # WARNING: no `faiResilience`. A LAN hop (<1ms), the same justification as `router`.
      #
      # WARNING: the "connection is not using a post-quantum key exchange" notice shows up on
      # EVERY connection and is NOT a mistake in our config: mlkem768x25519 only exists from
      # OpenSSH 9.9 onward, and Windows 11 (build 26200) still ships 9.5. It goes away on its own
      # when MS updates Win32-OpenSSH. It can be silenced with `WarnWeakCrypto = "no"` (which
      # exists in our 10.4), and that is precisely why it is NOT here: silencing it per host
      # hides the server's real lag, and the day it gets fixed would go unnoticed. The warning is
      # honest noise.
      #
      # WARNING: authorized_keys LIVES ON WINDOWS, out of Nix's reach, so this declares only the
      # CLIENT SIDE, and today the login still falls back to a PASSWORD. And `ssh-copy-id` does
      # NOT work here: it assumes a POSIX shell on the other end, and on the other end there is
      # cmd.exe. MEASURED (10/08): the `v1cferr` over there is an ADMINISTRATOR (`whoami /groups`
      # brings BUILTIN\Administrators, SID S-1-5-32-544), and that decides the file: for a member
      # of the group, the Windows sshd IGNORES `~/.ssh/authorized_keys` and reads ONLY the one
      # below. A manual step, in PowerShell as administrator ON my brother's machine:
      #   Add-Content C:\ProgramData\ssh\administrators_authorized_keys '<id_ed25519.pub>'
      #   icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r `
      #     /grant "Administrators:F" /grant "SYSTEM:F"
      # The `icacls` is not decoration: the sshd REFUSES the file (and falls back to the
      # password, silently on the client side) if anybody else can write to it.
      #
      # WARNING: a literal IP, and it comes from DHCP. If the router hands out another address
      # the alias breaks, and the fix is a DHCP reservation on the OpenWrt, not one more `my.*`
      # option here.
      #
      # The `RemoteCommand` swaps cmd.exe for GIT BASH, which is already installed there
      # (`where git` gives C:\Program Files\Git\cmd\git.exe). `where bash` does NOT find that
      # bash because only `Git\cmd` is on the PATH and bash.exe lives in `Git\bin`, hence the
      # absolute path here. The only `bash` on the PATH is `C:\Windows\System32\bash.exe`, which
      # is NOT bash: it is the legacy WSL stub, and the machine has no distro installed
      # ("Windows Subsystem for Linux has no installed distributions").
      #
      # REFUSED: swapping the shell through the registry
      # (`HKLM:\SOFTWARE\OpenSSH\DefaultShell`). It is global, and it would change the shell of
      # EVERY SSH session on the machine, the owner's included. On the client side the choice is
      # ours alone and it goes away together with this file.
      cesar = {
        HostName = "192.168.1.40";
        User = "v1cferr";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
        RequestTTY = "yes"; # a RemoteCommand with no TTY is an interactive shell with no echo and no readline
        RemoteCommand = ''"C:\Program Files\Git\bin\bash.exe" -l -i'';
      };

      # The SAME host, without `RemoteCommand`, and it is not duplication: `RemoteCommand` and a
      # command line are MUTUALLY EXCLUSIVE in ssh ("Cannot execute command-line and remote
      # command"), so with the block above `ssh cesar <cmd>`, `scp` and `rsync` STOP WORKING.
      # This twin is the declarative way out: `cesar` to sit down and work, `cesar-cmd` to copy a
      # file and run a one-off command. The alternative was memorizing
      # `-o RemoteCommand=none` on every invocation, which is exactly the kind of thing the repo
      # exists so you do not have to remember.
      cesar-cmd = {
        HostName = "192.168.1.40";
        User = "v1cferr";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
      };

      # A support VM at FAI.
      fai-vm = faiResilience // {
        HostName = "200.136.209.248";
        User = "v1cferr";
        Port = 22;
        SetEnv = {
          TERM = "xterm-256color";
        };
      };
    };
  };
}
