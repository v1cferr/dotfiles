# Auto-start Hyprland (uwsm-managed) on TTY1 login.
# "uwsm check may-start" falha se já houver sessão gráfica ativa, então isso
# não conflita com o login via display manager (greetd, que lança a sessão via
# uwsm em outra VT) — nem dispara um segundo Hyprland num console TTY1.
if uwsm check may-start && [ "${XDG_VTNR:-0}" -eq 1 ]; then
    exec uwsm start hyprland.desktop
fi
