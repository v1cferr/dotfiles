# Spotify and spicetify

`home/apps/spotify.nix`. The theme is the easy line; what took the reading was proving that the
patch does not eat the flag Spotify needs to start at all.

## Why this is declarable, when it looked like it was not

The first read of the Arch audit said to DROP spicetify, on the grounds that it patches the app
in place and the store is read-only. That premise was wrong. `spicetify-nix` never mutates
anything: `spicetifyBuilder` is `spotify.overrideAttrs`, so the patching happens INSIDE a
derivation and the result is a normal package.

## Gerg-L and not the-argus

The fork everybody's tutorial links, `the-argus/spicetify-nix`, is ARCHIVED, and its own README
points at [`Gerg-L/spicetify-nix`](https://github.com/Gerg-L/spicetify-nix), which is what the
[NixOS wiki](https://wiki.nixos.org/wiki/Spicetify-Nix) recommends too. Measured on 08/09/2026:
`nix flake metadata` reports it modified two days earlier, so it is alive.

## `--no-zygote` survives, and that was the real question

The overlay in `flake.nix` exists because the CEF zygote crashes here, and losing that flag means
Spotify does not open. Verified statically rather than hoped for:

```console
$ nix eval --raw .#nixosConfigurations.nixos-kingston.pkgs.unstable.spotify.postFixup
wrapProgram $out/bin/spotify --add-flags "--no-zygote"
```

The builder's `overrideAttrs` sets `name`, `nativeBuildInputs`, `postInstall` (concatenated onto
the old one, which is EMPTY here) and, conditionally, `fixupPhase`. It never touches
`postFixup`, so the flag rides through. Confirm it on any rebuild that changes this package:

```bash
grep -c no-zygote "$(nix eval --raw \
  '.#nixosConfigurations.nixos-kingston.config.home-manager.users.v1cferr.programs.spicetify.spicedSpotify')/bin/spotify"
```

## `wayland` stays UNSET on purpose

That conditional `fixupPhase` is the one thing that WOULD replace the phase, and it only applies
when `wayland != null`. The option's default is `null`, meaning "rely on `$NIXOS_OZONE_WL`",
which `system/desktop/desktop.nix` already sets to `1` for every Electron app on this machine.
So leaving it alone keeps one owner for that decision AND keeps the fixup phase intact. Setting
`wayland = true` would hardcode the ozone flags here and drop the phase that carries
`--no-zygote`, which is a lot of damage for a flag that is already set system-wide.

## The theme, and the check that comes for free

`theme = spicePkgs.themes.text` with `colorScheme = "TokyoNight"`, which is exactly what the Arch
`config-xpui.ini` declared (`current_theme = text`, `color_scheme = TokyoNight`), so this is a
port and not a new choice. The pinned `text/color.ini` carries 21 schemes and `[TokyoNight]` is
among them, verified in the store.

No need to be careful with that string: the builder runs `crudini --get` against the theme's
`color.ini` at BUILD time and exits 1 listing the valid values, so a typo fails loudly instead of
producing an unthemed Spotify.

## Three owners became one

`programs.spicetify` puts `createdPackages` (`[ spicedSpotify ] ++ theme.extraPkgs`) into
`home.packages` by itself, so leaving `unstable.spotify` in the central list would install TWO
Spotifys and let the autostart open the unthemed one, which is rule 14's silent drift with a
visible symptom. What changed, all in the same commit:

- `home/packages.nix` no longer lists it, since the module installs it (rule 4)
- `home/desktop/autostart.nix` reads `config.programs.spicetify.spicedSpotify` instead of
  `unstable.spotify`, so the menu and the autostart cannot diverge
- the overlay stays where it is, feeding `spotifyPackage`

`spicetifyPackage` is `unstable.spicetify-cli` and not the stable one, so both halves come from
the channel the Spotify comes from: 2.44.0 against 1.2.95 at the time of writing.

## This one does NOT hit the clobber trap

Worth stating, since adopting `programs.gh` and `programs.atuin` on the same day both failed
activation that way: spicetify's home-manager module is four lines and sets `home.packages` and
nothing else. It writes no file into `~/.config`, so there is no file to clobber and the switch
goes through on the first try. The trap and when `force` is the answer:
[`repo/packages.md`](../repo/packages.md).

## What proves it worked

Measured on the built output rather than by opening the app:

```bash
grep -o no-zygote .../spicetify-text/bin/spotify        # the flag survived
ls .../spicetify-text/share/spotify/Apps/xpui/          # spicetify-config.json is there
grep -l 1a1b26 .../share/spotify/Apps/xpui/colors.css   # TokyoNight's background
```

And that `home.packages` holds exactly ONE of them, which is the duplicate this change was
about: `["spicetify-text"]`.
