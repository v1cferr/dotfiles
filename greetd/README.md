# greetd — display manager + greeter quickshell

Substitui o SDDM. O greetd lança um **Hyprland mínimo** (usuário `greeter`) que sobe
um **greeter em quickshell** com cara de hyprlock: wallpaper fixo do Arch + login + quote
PT-BR + painel de serviços ao vivo no monitor primário (DP-1), e GIF em tela cheia no
secundário (HDMI-A-1). Ao autenticar, lança a sessão real via `uwsm` (segue uwsm-managed).

## Arquitetura

```
boot → greetd (vt 2) → Hyprland mínimo (greeter) → qs greeter.qml
                                                       │ lê /run/greeter-status/status.json
   root: greeter-status.service (loop ~3s) ───escreve──┘  (+ gif-*.gif)
   login OK → Greetd.launch(["uwsm","start","-e","-D","Hyprland","hyprland.desktop"])
```

O greeter roda sem privilégio (não acessa docker; `/home` é 710 e ele nem entra lá).
Toda coleta privilegiada (docker stats, sensors, nvidia-smi, quote, cópia de GIFs) é
feita pelo **coletor root** e exposta via JSON mundo-legível em `/run`. O wallpaper do
primário é fixo (`arch_hero_flipped.png`), instalado em `/etc/greetd/wallpaper.png`.

## Arquivos

| Caminho (repo) | Vai para | O quê |
|---|---|---|
| `etc/greetd/config.toml` | `/etc/greetd/` | entrypoint do greetd (vt 2, default_session) |
| `etc/greetd/hyprland-greeter.conf` | `/etc/greetd/` | compositor mínimo (monitores, env Nvidia, teclado br-abnt2) |
| `etc/greetd/quickshell/greeter.qml` | `/etc/greetd/quickshell/` | UI do greeter (multi-monitor, auth, painel) |
| `etc/systemd/system/greeter-status.service` | `/etc/systemd/system/` | coletor root (loop) |
| `etc/tmpfiles.d/greeter-status.conf` | `/etc/tmpfiles.d/` | cria `/run/greeter-status` |
| `../scripts/greetd/collect-status.sh` | `/usr/local/lib/greetd/` | gera o status.json + assets |
| `../scripts/greetd/deploy.sh` | — | instalador (configs + coletor) |
| `../scripts/greetd/switch-to-greetd.sh` | — | habilita o greetd como DM |

## Deploy / migração

```bash
sudo pacman -S greetd
sudo ~/dotfiles/scripts/greetd/deploy.sh        # configs + coletor

# (opcional) dry-run sem reiniciar, numa VT livre:
sudo systemctl start greetd     # senha real loga; depois: sudo systemctl stop greetd

# habilita o greetd como DM (mantenha SSH aberto):
sudo ~/dotfiles/scripts/greetd/switch-to-greetd.sh && sudo reboot
```

Recuperação: se o greeter não subir, via SSH ou console (Ctrl+Alt+F3) rode
`sudo systemctl disable greetd && sudo reboot` (o greetd traz o `agreety`, um
greeter texto de emergência).

## Notas

- **Nvidia:** o env do driver é replicado no `hyprland-greeter.conf`; sem blur/animations
  no compositor pra estabilidade. Maior risco é o Hyprland-as-greeter não subir — por isso
  o teste standalone antes do cutover.
- **vt 2:** deixa a tty1 livre pra console/recovery e evita corrida com o `~/.zprofile`.
- **GIFs/quote:** reusam os assets do hyprlock (`wallpapers/.../lockscreen-gifs/`,
  `hypr/.../lockscreen_quotes.tsv`); como o greeter abre 1x por boot, a quote/GIF são por boot.
- **`/run` é tmpfs:** o coletor copia só ~4 GIFs (nunca os 1.4G).
