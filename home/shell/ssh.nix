# The SSH client config. The private key is state, so it comes from the backup (rule 6).
# Every timeout here is sized to VS Code's 17s budget: docs/notes/network/ssh.md
{ config, ... }:

let
  ws = config.my.fai.workstation; # SSOT: home/net/fai-workstation.nix (rule 11)
  t480 = config.my.t480; # SSOT: home/net/t480.nix, shared with the `t480` RDP wrapper

  # Sized to fit VS Code Remote-SSH's FIXED 17s budget, not to comfort.
  faiResilience = {
    ServerAliveInterval = 15; # an encrypted keepalive every 15s: it holds the idle session on the SonicWall
    # 8 and not 20: a longer tolerance left the multiplexed master stuck in a dead tunnel.
    ServerAliveCountMax = 8;
    TCPKeepAlive = "no"; # the kernel's keepalive drops before the deadline above; SSH's is in charge
    ControlMaster = "auto"; # Remote-SSH opens several connections, so multiplex them all onto one TCP
    ControlPath = "~/.ssh/cm-%r@%h:%p"; # the master's socket (per user/host/port)
    ControlPersist = "10m"; # the master survives 10 min past the last channel: reopening becomes instant
    # 7x2 = 14 s worst case, INSIDE the 17 s. It was 15x3 and VS Code gave up mid-attempt.
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
      # The home router. No faiResilience: this is a LAN hop, and inheriting it would be cargo cult.
      # A reflash regenerates the Dropbear host key, and the key install: docs/notes/network/ssh.md
      router = {
        HostName = "192.168.1.1";
        User = "v1cferr";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      # My brother's PC (Windows 11, OpenSSH 9.5), which is where every trap here comes from.
      # The admin authorized_keys path and the Git Bash swap: docs/notes/network/ssh.md
      cesar = {
        HostName = "192.168.1.40";
        User = "v1cferr";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
        RequestTTY = "yes"; # a RemoteCommand with no TTY is an interactive shell with no echo and no readline
        # The leading `&` is PowerShell's call operator: without it the quoted path is just a string.
        RemoteCommand = ''& "C:\Program Files\Git\bin\bash.exe" -l -i'';
      };

      # The SAME host with no RemoteCommand, and NOT duplication: the two are mutually exclusive in
      # ssh, so without this twin `scp` and `rsync` stop working.
      cesar-cmd = {
        HostName = "192.168.1.40";
        User = "v1cferr";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
      };

      # My mother's ThinkPad T480 (Windows 11 IoT LTSC): sshd binds the TUNNEL address only, and
      # the Windows side is owned by a repo on that machine: docs/notes/network/ssh.md
      t480 = {
        HostName = t480.host;
        User = t480.user;
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
