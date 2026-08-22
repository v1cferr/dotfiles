# My mother's T480: the host's SSOT (rule 11) plus `t480`, the RDP wrapper.
# Why RDP and not Moonlight when the lid is shut: docs/notes/network/sunshine.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  t = config.my.t480;

  # The account is the FIRST argument when it is not a freerdp flag, so `t480` and `t480 mae`
  # both read naturally and anything after that still reaches the client untouched.
  rdpCli = pkgs.writeShellApplication {
    name = "t480";
    runtimeInputs = [ pkgs.freerdp ];
    text = ''
      account='${t.user}'
      case "''${1:-}" in
        "" | -* | /*) ;;
        *)
          account="$1"
          shift
          ;;
      esac

      echo "t480: ${t.host} as $account   (RShift+G releases the keyboard, RShift+D disconnects)"

      # `name:` and not `ignore`: Windows signs RDP with a self-signed cert whose CN is the
      # COMPUTER name, so telling freerdp what to expect keeps the check instead of dropping it.
      exec sdl-freerdp \
        /v:${t.host} \
        /d:${t.computerName} \
        "/u:$account" \
        /cert:tofu,name:${t.computerName} \
        /dynamic-resolution \
        +clipboard \
        "$@"
    '';
  };
in
{
  # The Windows side of this machine is owned by a repo ON it, not by this tree (rule 14).
  options.my.t480 = {
    host = lib.mkOption {
      type = lib.types.str;
      default = "10.10.10.6";
      description = "The T480's WireGuard address, which is the ONLY way in (its sshd binds it).";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "v1cferr";
      description = "The maintenance account over there, the one that holds my SSH key.";
    };
    owner = lib.mkOption {
      type = lib.types.str;
      default = "mae";
      description = "My mother's account. Over RDP it RECONNECTS to her session instead of replacing it.";
    };
    computerName = lib.mkOption {
      type = lib.types.str;
      default = "DESKTOP-MEM12EE";
      description = "The Windows computer name: the RDP certificate's CN and the domain of a local login.";
    };
  };

  # freerdp stays on PATH beside the wrapper: same store path, so it costs nothing, and a one-off
  # with different flags should not have to fight the wrapper's defaults.
  config.home.packages = [
    rdpCli
    pkgs.freerdp
  ];
}
