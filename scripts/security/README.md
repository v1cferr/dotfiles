# scripts/security

Ferramentas de verificação de segurança do sistema.

## `aur-malware-check.sh`

Verifica se a máquina foi atingida pelo ataque de *supply-chain* da AUR de
**junho/2026** (infostealer/cryptominer injetado via `npm/bun install
atomic-lockfile | js-digest | lockfile-js` em PKGBUILDs de maintainers
maliciosos — contas `krisztinavarga`, `custodiatovar`, `veramagalhaes`, npm
`herbsobering`).

### O que checa

1. **Pacotes AUR instalados** (`pacman -Qmq`) × lista de ~1600 pacotes
   comprometidos.
2. **npm/bun maliciosos** em `~/.npm`, `~/.bun`, `~/.cache` e `node_modules`.
3. **Rootkit eBPF**: `/sys/fs/bpf/hidden_{pids,names,inodes}`.
4. **Persistência systemd** referenciando IOCs.
5. **C2 `.onion`** em `~/.config` (e `/etc`, `/var/lib` se rodar com sudo) +
   cryptominer (`monero-wallet-gui`).
6. **`pacman.log`** na janela do ataque (09–12/jun/2026).

### Uso

```bash
# Checagem padrão (usuário)
~/dotfiles/scripts/security/aur-malware-check.sh

# Cobertura completa (varre /etc, /var/lib, lê pacman.log)
sudo ~/dotfiles/scripts/security/aur-malware-check.sh

# Atualiza a lista de comprometidos antes de checar
~/dotfiles/scripts/security/aur-malware-check.sh --refresh

# Ignora a janela de datas e varre todo o pacman.log
~/dotfiles/scripts/security/aur-malware-check.sh --all-time
```

**Exit codes:** `0` limpo · `2` possível comprometimento · `1` erro.

### Dados (`data/`)

Snapshot **versionado** das listas de IOCs para rodar offline / em DR:

| Arquivo                      | Conteúdo                                      |
| ---------------------------- | --------------------------------------------- |
| `package_list.txt`           | ~1600 pacotes AUR comprometidos               |
| `malicious_npm_packages.txt` | pacotes npm/bun do payload                    |
| `iocs.txt`                   | hashes ELF, C2, paths de persistência, contas |

Fonte agregada: [`lenucksi/aur-malware-check`](https://github.com/lenucksi/aur-malware-check)
(IFIN Discourse, Sonatype, Socket.dev). Use `--refresh` para sincronizar com o
upstream.

> Em caso de detecção real: **troque todas as credenciais** (GitHub PAT, SSH,
> tokens, cookies/sessões) e reinstale o sistema do zero — o payload é um
> infostealer com persistência.
