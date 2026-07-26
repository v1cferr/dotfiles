# ═══════════════════════════════════════════════════════════════════════════
# MANGOHUD — overlay de desempenho nos jogos (FPS, temps, uso, clocks…).
#
# Config 100% declarada aqui (gera ~/.config/MangoHud/MangoHud.conf). A INJEÇÃO
# no jogo vem do toggle `mangohud: true` do bottle (Bottles) — este módulo só
# CONFIGURA o overlay que aquele injeta. Como o bottle mapeia $HOME, o overlay
# lê este conf normalmente. Toggle mostrar/ocultar: Shift(dir)+F12 (muda embaixo).
#
# Ressalvas do driver `xe` (Arc B580): `gpu_power` e `gpu_fan` provavelmente
# ficam VAZIOS — a Arc não expõe potência/fan por hwmon hoje (já verificamos).
# Deixo ligados: não quebram nada e passam a aparecer se um kernel futuro expor.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  programs.mangohud = {
    enable = true;

    settings = {
      # ── FPS + frametime ──
      fps = true; # frames por segundo
      frametime = true; # tempo de frame (ms)
      frame_timing = true; # gráfico de frametime
      histogram = true; # histograma do frametime

      # ── CPU ──
      cpu_stats = true; # uso total (%)
      cpu_temp = true; # temperatura
      cpu_power = true; # consumo em W (RAPL — funciona no i5-11400)
      cpu_mhz = true; # clock atual
      core_load = true; # uso por núcleo
      cpu_load_change = true; # colore o número conforme a carga

      # ── GPU (Arc B580 / xe) ──
      gpu_stats = true; # uso (%)
      gpu_temp = true; # temperatura do core
      gpu_mem_temp = true; # temperatura da VRAM (sensor existe; no xe pode ficar vazio)
      gpu_core_clock = true; # clock do core
      gpu_mem_clock = true; # clock da VRAM
      gpu_power = true; # consumo em W (xe não expõe hoje → pode ficar vazio)
      gpu_fan = true; # RPM da fan (suporte p/ Arc incerto → pode ficar vazio)
      vram = true; # VRAM usada
      gpu_name = true; # nome da placa
      gpu_load_change = true; # colore conforme a carga

      # ── Memória / I-O de disco ──
      ram = true; # RAM usada (total do sistema)
      procmem = true; # RAM usada só pelo processo do jogo
      swap = true; # uso de swap
      io_read = true; # leitura de disco (MiB/s)
      io_write = true; # escrita de disco (MiB/s)

      # ── Info do app/driver ──
      vulkan_driver = true; # driver Vulkan em uso
      engine_version = true; # engine (DXVK/VKD3D/…)
      wine = true; # versão do Wine/Proton
      resolution = true; # resolução de render
      throttling_status = true; # avisa se há throttle térmico/power
      time = true; # relógio no overlay (útil p/ screenshots/gravações)

      # ── Aparência / posição ──
      position = "top-left"; # canto do overlay
      font_size = 20; # tamanho da fonte
      background_alpha = 0.4; # transparência do fundo
      round_corners = 8; # cantos arredondados
      table_columns = 3; # colunas da tabela

      # ── Toggle mostrar/ocultar (troque a tecla se quiser) ──
      toggle_hud = "Shift_R+F12";
    };
  };
}
