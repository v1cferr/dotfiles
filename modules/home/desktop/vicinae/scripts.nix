# Vicinae script commands: my existing CLIs as searchable entries, each a checked writeShellApplication.
# The header format and how to add one: docs/notes/desktop/vicinae.md
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  inherit (pkgs)
    nerd-fonts
    python3
    runCommand
    util-linux
    writeShellApplication
    xdg-utils
    ;

  repo = osConfig.programs.nh.flake;

  # Each script's icon is a JetBrainsMono Nerd Font glyph (the UI font, stylix.nix), cut out as an
  # SVG in the palette's text color. Looked up by glyph NAME, so a missing one fails the build.
  icon =
    glyph:
    runCommand "vicinae-icon-${glyph}.svg"
      {
        nativeBuildInputs = [ (python3.withPackages (p: [ p.fonttools ])) ];
        font = "${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf";
        inherit glyph;
        fill = "#${config.my.theme.palette.text}";
      }
      ''
        python3 - <<'PY'
        import os
        from fontTools.ttLib import TTFont
        from fontTools.pens.svgPathPen import SVGPathPen
        from fontTools.pens.boundsPen import BoundsPen
        font = TTFont(os.environ["font"])
        glyphs = font.getGlyphSet()
        name = os.environ["glyph"]
        if name not in glyphs:
            raise SystemExit(f"no glyph named {name} in the font")
        bounds = BoundsPen(glyphs)
        glyphs[name].draw(bounds)
        x0, y0, x1, y1 = bounds.bounds
        side = max(x1 - x0, y1 - y0) * 1.15
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        path = SVGPathPen(glyphs)
        glyphs[name].draw(path)
        # Font units grow upward and SVG units downward, hence the flip around the glyph's center.
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{cx - side / 2} {-cy - side / 2} {side} {side}">'
               f'<path transform="scale(1,-1)" fill="{os.environ["fill"]}" d="{path.getCommands()}"/></svg>')
        open(os.environ["out"], "w").write(svg)
        PY
      '';

  # The @vicinae header is plain comments under the shebang, so shellcheck still sees a script.
  # The commands are called by name, as keybinds.lua does: their modules own the derivations.
  mkScript =
    {
      name,
      title,
      group,
      glyph,
      mode ? "silent",
      confirm ? false,
      text,
    }:
    writeShellApplication {
      inherit name;
      runtimeInputs = [
        util-linux # setsid, so a GUI child outlives the script
        xdg-utils
      ];
      text = ''
        # @vicinae.schemaVersion 1
        # @vicinae.title ${title}
        # @vicinae.mode ${mode}
        # @vicinae.packageName ${group}
        # @vicinae.icon ${icon glyph}
        ${lib.optionalString confirm "# @vicinae.needsConfirmation true"}
        ${text}
      '';
    };

  openUrl = name: title: glyph: url: {
    inherit name title glyph;
    group = "Links";
    text = "xdg-open ${lib.escapeShellArg url}";
  };

  scripts = map mkScript [
    {
      name = "vpn-fai";
      glyph = "md-shield_lock_outline";
      title = "Connect FAI VPN";
      group = "VPN";
      mode = "compact";
      text = "vpn connect fai";
    }
    {
      name = "vpn-ufscar";
      glyph = "md-shield_lock_outline";
      title = "Connect UFSCar VPN";
      group = "VPN";
      mode = "compact";
      text = "vpn connect ufscar";
    }
    {
      name = "vpn-disconnect";
      glyph = "md-lan_disconnect";
      title = "Disconnect VPN";
      group = "VPN";
      mode = "compact";
      text = "vpn disconnect all";
    }
    {
      name = "ssh-workstation";
      glyph = "md-console_line";
      title = "SSH: FAI workstation";
      group = "Desktop";
      text = "setsid -f kitty ssh workstation";
    }
    {
      name = "restart-quickshell";
      glyph = "md-restart";
      title = "Restart Quickshell";
      group = "Desktop";
      text = "qs-restart";
    }
    {
      name = "shuffle-wallpapers";
      glyph = "md-image_multiple_outline";
      title = "Shuffle wallpapers";
      group = "Desktop";
      text = "wallpaper-shuffle both";
    }
    {
      name = "lock-session";
      glyph = "md-lock_outline";
      title = "Lock session";
      group = "Desktop";
      text = "loginctl lock-session";
    }
    {
      name = "away-screen";
      glyph = "md-moon_waning_crescent";
      title = "Away screen";
      group = "Desktop";
      # A beat later, so the Enter that launched this is released before the screen starts listening.
      text = "setsid -f sh -c 'sleep 0.5; qs ipc call away on'";
    }
    {
      name = "keybinds";
      glyph = "md-keyboard_outline";
      title = "Show keybind cheatsheet";
      group = "Desktop";
      # Detached, so the cheatsheet's dmenu opens after this command's window has closed.
      text = "setsid -f keybinds-cheatsheet";
    }
    {
      # A visible terminal: nh's sudo prompt and the build log stay in front of me.
      name = "nixos-rebuild";
      glyph = "linux-nixos";
      title = "NixOS rebuild (switch)";
      group = "System";
      confirm = true;
      text = "setsid -f kitty --hold --title 'NixOS rebuild' zsh -ic rebuild";
    }
    {
      name = "dotfiles-code";
      glyph = "md-microsoft_visual_studio_code";
      title = "Open dotfiles in VS Code";
      group = "Links";
      text = "setsid -f code ${lib.escapeShellArg repo}";
    }
    (openUrl "fai-dashboard" "Open FAI Dashboard" "md-view_dashboard_outline"
      "https://dashboard.sup.fai.ufscar.br"
    )
    (openUrl "github" "Open GitHub" "md-github" "https://github.com/v1cferr")
    (openUrl "dotfiles-github" "Open dotfiles on GitHub" "md-github"
      "https://github.com/v1cferr/dotfiles"
    )
  ];
in
{
  # One link per script in the default scripts dir, which Vicinae scans and watches.
  xdg.dataFile = lib.listToAttrs (
    map (s: lib.nameValuePair "vicinae/scripts/${s.name}" { source = lib.getExe s; }) scripts
  );
}
