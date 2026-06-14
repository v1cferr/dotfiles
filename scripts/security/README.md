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

# Checa também as atualizações AUR PENDENTES (antes de baixar)
~/dotfiles/scripts/security/aur-malware-check.sh --pending
```

**Exit codes:** `0` limpo · `2` possível comprometimento · `1` erro.

### Gate antes do `arch-update`

O `.zshrc` (`zsh/.zshrc`) define um wrapper da função `arch-update` que roda
`aur-malware-check.sh --refresh --pending` **antes** de aplicar qualquer
update. Se algum pacote comprometido aparecer entre os pendentes ou instalados,
ele aborta e exige confirmação explícita (`sim`) para prosseguir. Subcomandos
de info (`-l`, `-c`, `--tray`…) passam direto, sem checagem.

> `arch-update.conf` não tem hook nativo de pre-update, por isso o gate vive no
> shell. A checagem só dispara em invocação interativa no terminal — o systray
> chama o binário direto e não é afetado. Como a checagem roda a cada
> `arch-update`, não há timer agendado: o gate já cobre o uso normal.

### Dados (`data/`)

Snapshot **versionado** das listas de IOCs para rodar offline / em DR:

| Arquivo                      | Conteúdo                                      |
| ---------------------------- | --------------------------------------------- |
| `package_list.txt`           | ~1600 pacotes AUR comprometidos               |
| `malicious_npm_packages.txt` | pacotes npm/bun do payload                    |
| `iocs.txt`                   | hashes ELF, C2, paths de persistência, contas |

Fonte agregada: [`lenucksi/aur-malware-check`](https://github.com/lenucksi/aur-malware-check)
(IFIN Discourse, Sonatype, Socket.dev). O `--refresh` sincroniza do `HEAD` do
upstream a cada run — o snapshot em `data/` é só fallback offline. Não pinamos
um commit de propósito: numa lista de IOCs, frescor importa mais que
reprodutibilidade (pinar a deixaria estagnada). A lista é só nomes comparados
com `comm`/`grep`, não executa nada — o pior caso de um upstream ruim é um falso
positivo/negativo, não execução de código.

> ⚠️ **Fonte com prazo de validade.** Este repo é mantido por voluntários em
> torno do incidente de **junho/2026**; em algum momento ele para de receber
> updates. Para este ataque específico serve bem; para um ataque futuro
> diferente, provavelmente surgirá outra fonte. **Revisar a relevância da fonte
> ~dez/2026** e trocar/aposentar o script se o upstream estiver abandonado.

> Em caso de detecção real: **troque todas as credenciais** (GitHub PAT, SSH,
> tokens, cookies/sessões) e reinstale o sistema do zero — o payload é um
> infostealer com persistência.
