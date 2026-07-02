# ssh/

Pacote **híbrido** — tem duas metades com destinos diferentes:

## `.ssh/config` — config do **cliente** (via `stow`)

`~/.ssh/config` (aliases de host: `fai-vm`, `workstation`, LAN…). É stowado
para o `$HOME`:

```bash
cd ~/dotfiles
stow ssh
```

Um `.stow-local-ignore` faz o `stow` tocar **apenas** em `.ssh/`, ignorando o
lado `etc/` (senão criaria um `~/etc` errado). As **chaves privadas**
(`id_ed25519` etc.) NÃO ficam no repo — só o `config`.

> `workstation` = `200.136.209.229` (FAI, `superintendencia-server`). Só é
> alcançável com a VPN da FAI conectada.

## `etc/ssh/` — config do **servidor** sshd (via `deploy.sh`)

Drop-in `/etc/ssh/sshd_config.d/99-custom.conf`: porta **2222** + hardening
(`PermitRootLogin no`, `MaxAuthTries 3`, `UseDNS no`). Par do `fail2ban/`, que
protege essa porta. Config de `/etc`, **não** coberta pelo stow:

```bash
sudo ~/dotfiles/scripts/ssh/deploy.sh
```

O deploy **valida com `sshd -t`** antes de recarregar e faz `reload` (não
restart): não derruba sessões e, se a config estiver inválida, não aplica —
evitando lockout no SSH externo.
