# ssh/

Config do **servidor SSH** — drop-in `/etc/ssh/sshd_config.d/99-custom.conf`:
porta **2222** + hardening (`PermitRootLogin no`, `MaxAuthTries 3`, `UseDNS no`).
Par do `fail2ban/`, que protege essa porta. Config de `/etc`, aplicada por
`scripts/ssh/deploy.sh` (não é coberta pelo stow).

## Deploy

```bash
sudo ~/dotfiles/scripts/ssh/deploy.sh
```

O deploy **valida com `sshd -t`** antes de recarregar e faz `reload` (não
restart): não derruba sessões e, se a config estiver inválida, não aplica —
evitando lockout no SSH externo.
