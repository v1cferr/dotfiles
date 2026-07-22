#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Verificação pós-switch: sops + senha + fail2ban + cloudflare-dyndns.
# Utilitário local (gitignored). set sem -e: roda TODAS as checagens mesmo que
# uma falhe.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

echo "════════ sops: segredos decriptados em runtime ════════"
sudo ls -l /run/secrets/ /run/secrets-for-users/ 2>&1

echo
echo "════════ senha do usuário (1 = tem senha via sops) ════════"
sudo grep -c '^v1cferr:' /etc/shadow

echo
echo "════════ fail2ban (jail sshd na 2222) ════════"
sudo fail2ban-client status sshd 2>&1 | head -8

echo
echo "════════ cloudflare-dyndns (atualizou ssh.v1cferr.dev?) ════════"
systemctl status cloudflare-dyndns --no-pager 2>&1 | tail -15
