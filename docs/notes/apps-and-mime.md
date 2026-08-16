# Apps and MIME associations

`home/apps/media.nix`, `office.nix`, `mangohud.nix`, `openal.nix`.

home-manager merges `defaultApplications` from EVERY module into a single `mimeapps.list`, so
these modules each declare only their own types and the result composes. `home/desktop/xdg.nix`
holds the browser plus text/code, and `home/apps/curseforge.nix` holds the URL schemes.

## Media: the KDE Gear stack

Gwenview (images) and Okular (documents) because this system is already Qt/Kvantum plus Dolphin, so
they come in themed for free and integrate with the file manager (open-with, thumbnails).
`kimageformats` plus `qtimageformats` give the modern formats (AVIF/HEIF/JXL/WebP/RAW/PSD).

mpv is configured through its `programs.*` module, so it stays idiomatic: `hwdec = "auto-safe"`
decodes on the GPU when that is safe, and `vo = "gpu-next"` is the modern output, with better
HDR/tone-mapping on Wayland. VLC is the association default; mpv is left for opening by hand or
from the CLI.

### ALWAYS use shared-mime-info's CANONICAL type

An ALIAS does not match in the lookup and the entry dies in silence. Three cases hit here:

| Wrong (alias) | Right (canonical) | What broke |
| --- | --- | --- |
| `image/heic` | `image/heif` | .heic never reached Gwenview |
| `image/x-psd` | `image/vnd.adobe.photoshop` | Gwenview's own `.desktop` declares only the alias |
| `video/x-msvideo` | `video/vnd.avi` | .avi fell into mpv instead of VLC |

Two more that are easy to miss: `image/vnd.microsoft.icon` (.ico) is read natively by Qt but is not
declared in Gwenview's `.desktop`, and the AUDIO types all have to be listed explicitly, because
otherwise `mpv.desktop` takes the association by claiming them in its own `.desktop`, against the
intent.

## Office: why OnlyOffice and not LibreOffice

OnlyOffice uses OOXML as its NATIVE format, so `.docx`/`.xlsx`/`.pptx` open with no shifted table
and no repagination, and the UI is a ribbon, just like Office 365.

LibreOffice is the NixOS community's default and has more features (Draw, Base, macros), but it is
native in ODF and CONVERTS OOXML, losing fidelity on a complex document. Switching is 1 line plus
the defaults.

**The fonts come from `system/hardware/fonts.nix`** (corefonts plus vista-fonts). The package is a
`buildFHSEnv` and `/etc/fonts` comes from the HOST (`build-fhsenv-bubblewrap`), so the system's
fontconfig already sees them. There is NO need for the "copy the .ttf into
`~/.local/share/fonts`" that the NixOS wiki tells you to do by hand (rule 3). See
[`fonts.md`](fonts.md).

**A trap**: OnlyOffice's `.desktop` claims 61 mimetypes, pdf, epub, `text/plain`, markdown and csv
included. The explicit defaults in `media.nix` (Okular) and `xdg.nix` (VS Code) still win, but if
they ever disappear, OnlyOffice starts opening PDFs and `.txt` files.

## OpenAL: the mute-game fix

`xdg.configFile."alsoft.conf"` forces the PulseAudio backend. It is read by ANY OpenAL-soft, the
one bundled with a game included.

Without it, the OpenAL 1.18.2 that ships with the HashLink/Heaps games (Northgard, Dead Cells,
Evoland) has no `pipewire` backend, since that only arrived in 1.20+, and inside the Steam
runtime's sandbox it falls into the wrong ALSA device and goes MUTE. `pulse` connects to the
`pipewire-pulse` socket, so sound comes out on the default sink.

## MangoHud

The config is 100% declared, generating `~/.config/MangoHud/MangoHud.conf`. The INJECTION into the
game comes from the bottle's `mangohud: true` toggle in Bottles; this module only CONFIGURES the
overlay that one injects. Since the bottle maps `$HOME`, the overlay reads this conf normally. The
show/hide toggle is Shift(right)+F12.

**Caveats of the `xe` driver on the Arc B580**: `gpu_power` and `gpu_fan` will probably be EMPTY,
since the Arc does not expose power or fan through hwmon today (checked). They are left on: they
break nothing, and they start showing up if a future kernel exposes them. `gpu_mem_temp` is in the
same category, the sensor exists but can stay empty.

`cpu_power` does work here, through RAPL on the i5-11400.
