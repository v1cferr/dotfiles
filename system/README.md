# system/

Configs base do Arch. Espelho de `/etc` (+ `/boot` como referência). Não é
coberto pelo stow; o que é seguro aplicar vai por `scripts/system/deploy.sh`.

## Aplicados pelo deploy

- `etc/pacman.conf` — config do pacman (repos, multilib, opções).
- `etc/pacman.d/hooks/fix-appstream-data.hook` — hook custom do pacman.
- `etc/makepkg.conf` + `etc/makepkg.conf.d/{rust,fortran}.conf` — build do AUR.

```bash
sudo ~/dotfiles/scripts/system/deploy.sh
```

O deploy valida o `pacman.conf` (`pacman-conf`) antes de sobrescrever.

## Só REFERÊNCIA (o deploy NÃO aplica)

- `etc/mkinitcpio.conf` — HOOKS/MODULES do initramfs.
- `boot/loader/` — entradas do systemd-boot. O `root=UUID` é **machine-specific**.

⚠️ Aplicar esses errado pode **quebrar o boot**. Numa máquina nova: use como
base, ajuste UUIDs/dispositivos e regenere (`mkinitcpio -P` e revise
`/boot/loader/`). Por isso ficam fora do deploy automático.
