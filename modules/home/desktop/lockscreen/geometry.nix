# The lock screen's ONE geometry model: every glass card per monitor and layout, read by the renderer
# (as JSON) and by the hyprlock labels. Offsets are from the screen's CENTER, y down: docs/notes/desktop/lockscreen.md
{ lib, rounding }:

let
  # A lock card is a MAJOR surface: the desktop's corner plus sp1, one step up the concentric scale.
  radius = rounding + 4;

  # `alpha` is the card's baseline opacity; the renderer raises it only where contrast needs it.
  card = id: x: y: w: h: alpha: {
    inherit id alpha radius;
    center = [
      x
      y
    ];
    size = [
      w
      h
    ];
  };

  # ── ASUS, 2560x1440: the prints' own language. The time, the date and who I am sit on a washi
  # cartouche (tanzaku) in a top corner, as a print sets its title, with my logo as the artist's
  # seal stamped over its corner; the art keeps the middle. The field and the quote, on light glass,
  # are centered at the foot. The cartouche and the seal are drawn on the LEFT and mirrored to the
  # right when that side of the print is calmer (render.py `side_of`). ──
  slip = card "slip" (-950) (-190) 260 760 0 // {
    material = "paper";
    radius = 4;
    sided = true;
  };
  seal = card "seal" (-850) 180 104 104 0 // {
    material = "hanko";
    radius = 6;
    sided = true;
  };
  # The field: hyprlock draws its state hairline on this glass, with the same corner.
  auth = card "auth" 0 330 480 70 0.3 // {
    edge = false;
  };
  # The quote on a light reading surface, its foot 70 px off the screen's edge.
  quote = card "quote" 0 530 1200 240 0.22;

  # ── LG, 1080x1920: independent Bento cards, each its own glass, the art visible between them.
  # 72 px margins, 24 px gaps, rows from 184 px down; the lower ~460 px stay the print. ──
  lgW = 1080;
  lgH = 1920;
  margin = 72;
  gap = 24;
  fullW = lgW - 2 * margin; # 936
  halfW = (fullW - gap) / 2; # 456
  # Each row's top and height, top to bottom: energy, Claude, system + processes, weather + media.
  rowH = [
    328
    328
    304
    240
  ];
  rowTop = i: builtins.foldl' (acc: h: acc + h + gap) 184 (lib.take i rowH);
  lgCard =
    id: col: row: w:
    let
      h = builtins.elemAt rowH row;
      cx =
        {
          full = 0;
          left = -(halfW + gap) / 2;
          right = (halfW + gap) / 2;
        }
        .${col};
    in
    card id cx (rowTop row + h / 2 - lgH / 2) w h 0; # the material (default.nix) sets the baseline
  energy = lgCard "energy" "full" 0 fullW;
  claude = lgCard "claude" "full" 1 fullW;
  system = lgCard "system" "left" 2 halfW;
  procs = lgCard "procs" "right" 2 halfW;
  weather = lgCard "weather" "left" 3 halfW;
  media = lgCard "media" "right" 3 halfW;
  # Ambient has no media card: the weather takes the whole last row instead of an empty surface.
  weatherWide = lgCard "weather" "full" 3 fullW;
in
{
  inherit radius;
  cards = {
    inherit
      slip
      seal
      auth
      quote
      ;
    inherit
      energy
      claude
      system
      procs
      weather
      media
      weatherWide
      ;
  };

  # Where the LG's text goes: x from the screen's LEFT edge, y from its CENTER (hyprlock halign
  # left, valign center), both measured from a card's top-left corner; `pad` is every card's inset.
  lg = rec {
    pad = 32;
    x = c: dx: lgW / 2 + builtins.elemAt c.center 0 - builtins.elemAt c.size 0 / 2 + dx;
    y = c: dy: builtins.elemAt c.center 1 - builtins.elemAt c.size 1 / 2 + dy;
    inner = c: builtins.elemAt c.size 0 - 2 * pad; # a card's text width
  };
  lgPos = x: y: "${toString x}, ${toString (-y)}";

  monitors = {
    primary = {
      size = [
        2560
        1440
      ]; # the declared logical size; the renderer prefers the live one
      layouts.main = [
        slip
        seal
        auth
        quote
      ];
    };
    secondary = {
      size = [
        lgW
        lgH
      ]; # rotated: 1920x1080 on its side
      layouts = {
        ambient = [
          energy
          claude
          system
          procs
          weatherWide
        ];
        media = [
          energy
          claude
          system
          procs
          weather
          media
        ];
      };
    };
  };

  # A hyprlock `position` for a point inside a card, center anchored: hyprlock's y grows UP.
  at =
    c: dx: dy:
    "${toString (builtins.elemAt c.center 0 + dx)}, ${toString (-(builtins.elemAt c.center 1 + dy))}";
}
