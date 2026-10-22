# `boot-theme`: the Limine wallpaper AND the Plymouth theme, drawn from ONE palette preset so the
# screens before the desktop wear its colors. Layout, assets and why: docs/notes/boot-and-storage/splash.md
{
  lib,
  runCommand,
  imagemagick,
  librsvg,
  nixos-icons,
  plymouth,
  # A preset from the desktop's own file (rule 11), never hexes copied here.
  preset ?
    let
      p = import ../../modules/home/desktop/palette-presets.nix;
    in
    p.presets.${p.default},
  # "official" is the blue logo as NixOS ships it; "accent" tints the white one with the palette.
  logoStyle ? "official",
  # The Limine canvas. It must match boot.loader.limine.style.interface.resolution.
  width ? 1920,
  height ? 1080,
  # Where the logo sits on the Limine canvas: under Limine's three header rows (y 200 at 2x2)
  # and above the tree, which starts near y 320 with ten generations. Measured in vm-limine.
  logoSize ? 88,
  logoTop ? 224,
}:

let
  name = "nixos-minimal";
  logoSvg =
    if logoStyle == "accent" then
      "${nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake-white.svg"
    else
      "${nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
  tint = lib.optionalString (logoStyle == "accent") "-fill '#${preset.accent}' -colorize 100";
  spinner = "${plymouth}/share/plymouth/themes/spinner";
in
assert lib.assertOneOf "logoStyle" logoStyle [
  "official"
  "accent"
];
runCommand "boot-theme-${name}"
  {
    nativeBuildInputs = [
      imagemagick
      librsvg
    ];
    passthru = { inherit name preset; };
  }
  ''
    logo() { rsvg-convert -w "$1" -h "$1" ${logoSvg} | magick png:- ${tint} "$2"; }

    # LIMINE: a flat canvas in `bg` with the logo on top. Centered style plus the same backdrop,
    # so a firmware that refuses 1920x1080 still shows the same color around it.
    mkdir -p $out/limine
    logo ${toString logoSize} logo-limine.png
    magick -size ${toString width}x${toString height} 'xc:#${preset.bg}' \
      logo-limine.png -gravity north -geometry +0+${toString logoTop} -composite \
      -strip $out/limine/wallpaper.png

    # PLYMOUTH (two-step, the C plugin of spinner/bgrt): it centers per head on its own, and a
    # looping throbber is indeterminate on purpose, since boot has no honest percentage.
    t=$out/share/plymouth/themes/${name}
    mkdir -p $t
    logo 128 $t/watermark.png

    # Three dots, a 1.2 s wave at plymouth's 30 fps: one dot brightens at a time, nothing moves.
    frames=36
    for f in $(seq 0 $((frames - 1))); do
      args=()
      for d in 0 1 2; do
        a=$(awk -v f="$f" -v d="$d" -v n="$frames" 'BEGIN {
          x = cos(2 * 3.14159265 * (f / n - d / 6)); if (x < 0) x = 0
          printf "%02x", int(255 * (0.25 + 0.75 * x * x))
        }')
        cx=$((12 + d * 24))
        args+=(-fill "#${preset.accent}$a" -draw "circle $cx,8 $((cx + 4)),8")
      done
      magick -size 72x16 xc:none "''${args[@]}" -strip \
        "$t/throbber-$(printf %04d $((f + 1))).png"
    done

    # The password dialog's assets, only so a prompt never renders without them (no LUKS here).
    for a in bullet capslock entry keyboard keymap-render lock; do
      cp ${spinner}/$a.png $t/
    done

    cat > $t/${name}.plymouth <<EOF
    [Plymouth Theme]
    Name=NixOS Minimal
    Description=The NixOS logo and three dots on the desktop palette.
    ModuleName=two-step

    [two-step]
    Font=Sans 12
    TitleFont=Sans 14
    ImageDir=$t
    DialogHorizontalAlignment=.5
    DialogVerticalAlignment=.62
    WatermarkHorizontalAlignment=.5
    WatermarkVerticalAlignment=.45
    HorizontalAlignment=.5
    VerticalAlignment=.62
    TitleHorizontalAlignment=.5
    TitleVerticalAlignment=.68
    Transition=none
    TransitionDuration=0.0
    BackgroundStartColor=0x${preset.bg}
    BackgroundEndColor=0x${preset.bg}
    MessageBelowAnimation=true

    [boot-up]
    UseEndAnimation=false

    [shutdown]
    UseEndAnimation=false
    Title=Shutting down

    [reboot]
    UseEndAnimation=false
    Title=Restarting
    EOF
  ''
