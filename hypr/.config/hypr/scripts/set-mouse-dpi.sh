#!/usr/bin/env bash
# ============================================================================
#  Força DPI fixo nos mouses Razer no login (workaround OpenRazer)
# ----------------------------------------------------------------------------
#  O DeathAdder V2 (1532:0084) NÃO expõe serial no descritor USB. No race de
#  enumeração o OpenRazer às vezes lê o serial truncado/zero e enumera o device
#  como UNKNOWN, aplicando o DPI default (1800) em vez do persistence (1600).
#  Aqui reaplicamos o DPI ATIVO via daemon, ignorando serial/perfil — então o
#  DPI fica determinístico todo login, não importa como o device enumerou.
#
#  Chamado por exec-once no autostart do Hyprland (o delay é tratado no Python,
#  que espera o openrazer-daemon subir).
#
#  Uso:  set-mouse-dpi.sh [DPI]      (default 1600)
# ============================================================================
DPI="${1:-1600}"

exec python3 - "${DPI}" <<'PY'
import sys, time

dpi = int(sys.argv[1])
try:
    import openrazer.client as razer
except Exception:
    sys.exit(0)                       # openrazer não instalado — silencioso

mgr = None
for _ in range(20):                   # espera o daemon (até ~10s)
    try:
        mgr = razer.DeviceManager()
        break
    except Exception:
        time.sleep(0.5)
if mgr is None:
    sys.exit(0)

for d in mgr.devices:
    try:
        if d.has("dpi"):
            d.dpi = (dpi, dpi)
            print("[set-mouse-dpi] %s -> DPI %d" % (d.name, dpi))
    except Exception as e:
        print("[set-mouse-dpi] falhou em %s: %s" % (getattr(d, "name", "?"), e))
PY
