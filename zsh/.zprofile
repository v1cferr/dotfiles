# Auto-start Hyprland (uwsm-managed) on TTY1 login.
# "uwsm check may-start" falha se já houver sessão gráfica ativa,
# então isso não conflita com o login via SDDM (que também usa uwsm).
if uwsm check may-start && [ "${XDG_VTNR:-0}" -eq 1 ]; then
    exec uwsm start hyprland.desktop
fi
