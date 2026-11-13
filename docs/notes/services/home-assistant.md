# Home Assistant updates

`modules/nixos/services/home-assistant.nix`, toggle `my.services.home-assistant`.

The stack is not declared here. It lives in
[home-automation](https://github.com/v1cferr/home-automation) as a compose file with
`restart: unless-stopped`, so dockerd is what starts it at boot. This module only owns ONE
automation: moving that container to the newest stable release.

## What runs

A daily oneshot at 05:00 (`Persistent`, so a missed run happens on the next boot):

```sh
docker-compose pull --quiet homeassistant
docker-compose up -d --remove-orphans homeassistant
```

The compose pins `ghcr.io/home-assistant/home-assistant:stable`, which upstream moves on every
release, patch releases included. `pull` downloads only when the tag moved, and `up -d` only
recreates the container when the image changed, so most days nothing restarts. The old image
is left dangling and the daily docker prune collects it after a week
([docker-prune](docker-prune.md)), which keeps a rollback target around for that long.

## Why a timer and not Watchtower

Watchtower is a container with the Docker socket mounted, which is root on the host handed to
a third-party image, and `containrrr/watchtower` is archived upstream (checked on 13/11/2026:
archived, last push 17/12/2025). A systemd timer is the repo's way to give an automation one
owner (rule 15), it runs under the shared sandbox (`my.systemd.hardened`: no network of its
own, home read-only), and the pull itself is done by dockerd.

## Why 05:00

After the docker prunes (04:30 and 04:45), so the three never fight over the NVMe, and at an
hour when a restart (about a minute without automations) bothers nobody.

## The cost of always-latest

Monthly releases can carry breaking changes, and nothing here reads them first: the owner
chose that on 13/11/2026. What softens it: the config is small and in git
(`homeassistant/configuration.yaml` and `packages/`), and Home Assistant validates its own YAML
on start and raises a repair issue instead of refusing to boot. To go back one release, set
the previous tag in the compose file and run `docker compose up -d`.

To see what a run did:

```sh
journalctl -u home-assistant-update -n 20
```
