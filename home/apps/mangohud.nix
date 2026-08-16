# MANGOHUD: a performance overlay in games (FPS, temps, usage, clocks and so on).
#
# The config is 100% declared here (it generates ~/.config/MangoHud/MangoHud.conf). The INJECTION
# into the game comes from the bottle's `mangohud: true` toggle (Bottles); this module only
# CONFIGURES the overlay that one injects. Since the bottle maps $HOME, the overlay reads this
# conf normally. The show/hide toggle: Shift(right)+F12 (set at the bottom).
#
# Caveats of the `xe` driver (Arc B580): `gpu_power` and `gpu_fan` will probably be EMPTY, since
# the Arc does not expose power/fan through hwmon today (we have checked). I leave them on: they
# break nothing and they start showing up if a future kernel exposes them.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  programs.mangohud = {
    enable = true;

    settings = {
      # ── FPS plus frametime ──
      fps = true; # frames per second
      frametime = true; # frame time (ms)
      frame_timing = true; # a frametime graph
      histogram = true; # a frametime histogram

      # ── CPU ──
      cpu_stats = true; # total usage (%)
      cpu_temp = true; # temperature
      cpu_power = true; # draw in W (RAPL, it works on the i5-11400)
      cpu_mhz = true; # the current clock
      core_load = true; # usage per core
      cpu_load_change = true; # it colors the number according to the load

      # ── GPU (Arc B580 / xe) ──
      gpu_stats = true; # usage (%)
      gpu_temp = true; # the core's temperature
      gpu_mem_temp = true; # the VRAM's temperature (the sensor exists; on xe it can stay empty)
      gpu_core_clock = true; # the core's clock
      gpu_mem_clock = true; # the VRAM's clock
      gpu_power = true; # draw in W (xe does not expose it today, so it can stay empty)
      gpu_fan = true; # the fan's RPM (Arc support uncertain, so it can stay empty)
      vram = true; # VRAM used
      gpu_name = true; # the card's name
      gpu_load_change = true; # it colors according to the load

      # ── Memory / disk I-O ──
      ram = true; # RAM used (the system's total)
      procmem = true; # RAM used by the game's process alone
      swap = true; # swap usage
      io_read = true; # disk reads (MiB/s)
      io_write = true; # disk writes (MiB/s)

      # ── App/driver info ──
      vulkan_driver = true; # the Vulkan driver in use
      engine_version = true; # the engine (DXVK/VKD3D/…)
      wine = true; # the Wine/Proton version
      resolution = true; # the render resolution
      throttling_status = true; # it warns if there is thermal/power throttling
      time = true; # a clock in the overlay (useful for screenshots/recordings)

      # ── Appearance / position ──
      position = "top-left"; # the overlay's corner
      font_size = 20; # the font size
      background_alpha = 0.4; # the background's transparency
      round_corners = 8; # rounded corners
      table_columns = 3; # the table's columns

      # ── The show/hide toggle (change the key if you want) ──
      toggle_hud = "Shift_R+F12";
    };
  };
}
