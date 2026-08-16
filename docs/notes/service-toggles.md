# The optional-service toggles

`system/services/toggles.nix` declares the LIST of keys that exist. Nothing is turned on there:
the value is each machine's decision, in `hosts/<host>/services.nix`.

## Why the declarations are centralized (04/08/2026)

`osConfig` only sees the NixOS namespace, so an option read by a home module (dropbox,
discord-rpc, cs2-backup) HAS to be declared by a system module. Spreading the declarations across
each service module would leave those three orphans needing a central file anyway, which is worse
than one list that doubles as a readable contract of what this repo knows how to turn on and off.

## Reading a flag

- system module: `config.my.services.<name>`
- home module: `osConfig.my.services.<name>`

## What stays out on purpose

The essentials are not toggleable, so they cannot be switched off by accident: tailscale,
mouse/logid, the hypr\* desktop, keyring, earlyoom, fail2ban, fwupd. The VPN is on demand, so it
stays out too.

## A new key is born false

`mkEnableOption` defaults to `false`, so a new service that does not come up is the expected
symptom; the remedy is adding the line to the host's panel.
