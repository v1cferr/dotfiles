# Migração Arch → NixOS — Contexto e Plano

> Documento de contexto gerado em 2026-07-12 a partir de uma consultoria com Claude Code.
> Objetivo: servir de briefing completo para outros chats/sessões sobre essa migração.

## 1. Objetivo do usuário (v1cferr)

- Sistema **inteiro declarativo**: recriar a máquina a partir de texto versionado (GitHub + servidor local, redundância) caso troque de máquina, o SSD morra, etc.
- Manter o **rice Hyprland + Quickshell** atual funcionando por anos — meta: chegar em **2032** com o mesmo sistema, dando manutenção contínua (manutenção não é problema, já faz isso no Arch).
- É **AI Engineer** (carreira profissional e acadêmica — FAI/UFSCar), então o ambiente Python/CUDA/LLM importa.

## 2. Sistema atual (analisado em 2026-07-12)

- **Arch Linux**, instalação com 222 dias, 1566 pacotes (242 explícitos + 35 AUR), kernel 7.1.3-arch1-2.
- i5-11400, **RTX 3050 (NVIDIA)**, 16GB RAM, root ext4 em NVMe Kingston (nvme1n1, 1TB).
- **Hyprland 0.55 + Quickshell** (barra, greeter via greetd, notificações, OSD — tudo QS; waybar/swaync/SDDM aposentados).
- Dual monitor: LG Ultragear 144Hz (DP-1) + LG TV 60Hz (HDMI-A-1, GIFs do hyprlock).
- A máquina é **desktop + homelab de produção ao mesmo tempo**: 16 containers Docker (jellyfin, stack *arr, open-webui, duo-streak, etc.), Caddy servindo `*.v1cferr.dev` público, WireGuard inbound, fail2ban, DDNS Cloudflare.
- Repo `~/dotfiles` já versiona quase tudo: **stow** para `$HOME`, `deploy.sh` por serviço para `/etc` (caddy, fail2ban, greetd, ssh, swap, wireguard, wol, refind, netextender...), timer systemd regenerando listas de pacotes a cada 5min, `RESTORE.md` (runbook DR), segredos criptografados fora do git.

**Diagnóstico central:** o setup atual já é uma "reimplementação manual e imperativa do NixOS". Cada peça mapeia 1:1 para módulo nativo (`services.caddy`, `services.fail2ban`, `services.greetd`, `zramSwap`, `hardware.openrazer`, `virtualisation.oci-containers`...). A disciplina declarativa já existe; falta só a ferramenta que a executa.

## 3. Veredito da consultoria

**Migrar vale a pena — o usuário é o público-alvo exato do NixOS.** Não é loucura; o objetivo declarado é literalmente o pitch do NixOS. Alternativas descartadas:

- **Fedora Silverblue / openSUSE MicroOS**: imutáveis mas não declarativos; Hyprland cidadão de 2ª classe.
- **Guix System**: par filosófico, mas repositório minúsculo, NVIDIA via canal externo, sem stack Hypr first-class.
- **Arch + Ansible**: provisioning declarativo-ish, não impede drift, duas fontes de verdade.
- **Híbrido Nix-sobre-Arch como destino final**: REJEITADO — declarativiza o `$HOME` (que o stow já resolve) e deixa imperativo o `/etc` + kernel + driver (onde mora a dor). Vale só como fase de aprendizado.

**Arquitetura escolhida: NixOS como base + distrobox com container Arch por cima** ("híbrido invertido"). A base é declarativa e imortal; o playground (pacman/yay/AUR de verdade, exportando apps pro host com `distrobox-export`) é mortal e não compromete nada. Container criado com `--nvidia` para GPU. `distrobox assemble` (arquivo ini versionado) torna até o playground semi-declarativo.

**Hierarquia de pacotes para se manter declarativo:** nixpkgs → flake de terceiro/NUR → derivation própria → distrobox (último recurso; app que morar meses no container merece ser promovido a derivation).

## 4. Pontos de atrito conhecidos (e antídotos)

| Atrito | Antídoto |
|---|---|
| Wheels Python/CUDA assumem FHS (`uv pip install torch` quebra) | `programs.nix-ld.enable = true` desde o dia 1 |
| Containers com GPU (open-webui etc.) | `hardware.nvidia-container-toolkit.enable = true` |
| Ambientes de pesquisa reproduzíveis | devShells + direnv (flake por projeto pinando Python/CUDA) |
| home-manager gera symlinks read-only (mata hot-reload do QML) | `mkOutOfStoreSymlink` apontando pro checkout do repo nos dirs editados quente (hypr, quickshell) |
| **NetExtender (SonicWall, VPN da FAI)** — pior caso: binário proprietário FHS + daemon NEService, sem pacote no nixpkgs | Empacotar com `buildFHSEnv`; re-engenheirar split-tunnel via sudoers. Reservar um fim de semana |
| ~5-6 pacotes AUR sem equivalente (antigravity-ide, perssua, pencil-dev-bin, claude-desktop) | Derivation própria / `appimageTools.wrapType2` / `nix-init` gera derivation de URL |
| Saudade do pacman | `nix shell nixpkgs#pkg` (efêmero, superpoder), `nix search`, `comma` |
| Saudade da wiki Arch | Continua servindo pra conceitos; camada NixOS = search.nixos.org + código do nixpkgs no GitHub |
| Canal | `nixpkgs-unstable` (rice precisa de Hyprland/QS frescos) |
| Segredos | sops-nix ou agenix desde o dia 1 (aposenta o tarball GPG) |

Notas: ~85% dos 35 pacotes AUR já existem no nixpkgs ou têm flake conhecido (claude-code, librewolf, localsend, bottles, rustdesk, sublime4, bibata-cursors, ventoy, onlyoffice; zen-browser e spicetify via flakes da comunidade). Quickshell e todo o stack Hypr são empacotados/first-class no Nix. `flake.lock` commitado = cápsula do tempo (o você-de-2032 rebuilda o sistema de 2026).

## 5. Estratégia de repositório

**Tudo no repo `dotfiles` atual, branch `main`, flake aditivo.** Stow e Nix coexistem **no repo, nunca na mesma máquina** (stow governa o Arch; home-manager governa o NixOS; compartilham os arquivos-fonte). Um repo, dois consumidores durante a transição; o stow se aposenta no cutover.

Estrutura proposta:

```
dotfiles/
├── flake.nix               # porta de entrada
├── flake.lock
├── nix/
│   ├── hosts/
│   │   ├── nixos-test.nix  # instalação de teste (2º NVMe)
│   │   └── desktop.nix     # definitivo (Kingston), hardware.nvidia
│   ├── modules/            # tradução dos deploy.sh (caddy, fail2ban, greetd, swap, wireguard, wol...)
│   ├── pkgs/               # "AUR pessoal": derivations (lz4json, netextender...)
│   └── home/               # home-manager consumindo os dirs stow existentes
├── hypr/ quickshell/ zsh/  # intocados (stow no Arch, HM no NixOS)
└── scripts/ homelab/ ...
```

Pegadinhas de flake-em-repo-existente:
1. Flakes só enxergam arquivos **rastreados pelo git** (`git add` antes do rebuild — erro clássico).
2. Cada eval copia o repo rastreado pra `/nix/store` — manter binários grandes fora do git (já é a prática: GIFs via manifesto).
3. Segredo rastreado = segredo legível na store — nunca rastrear (sops-nix resolve o fluxo).
4. Usar **disko** — particionamento declarativo; o layout de disco vira texto e a reinstalação teste→definitivo fica automática.

## 6. Plano faseado (estado em 2026-07-12)

**DECISÃO FINAL (13/jul):** staging será um **NVMe novo** substituindo o Netac moribundo no 2º slot M.2. Arch permanece no Kingston durante toda a adaptação.

1. ~~VM QEMU/KVM~~ → ~~instalação no Netac~~ → **NVMe novo no slot do Netac** (a comprar). Vantagens: disco limpo (sem Windows pra encolher, sem setor morto), `disko` particiona declarativamente do zero, teste em NVMe real.
2. **[pode rodar já, antes do NVMe chegar]** esqueleto do flake no repo + home-manager standalone no Arch para aprender a linguagem.
3. **Instalar NixOS de teste** no NVMe novo com o flake do repo. Ir adaptando os dotfiles para o Nix a partir do Arch (mesmo repo, consumidor duplo). Validar: greetd/greeter QS, barra, hyprlock+GIFs, dual-monitor, NVIDIA (VA-API, gamma do hyprsunset, vrr), NetExtender, stacks Docker.
4. **Cutover**: quando estiver redondo (uma semana sem bootar o Arch) → aplicar o mesmo flake no **Kingston (nvme1n1)**. NixOS vira a distro definitiva da workstation; troca futura de PC inteiro = reaplicar o flake. Arch aposentado.

## 7. Descobertas sobre o 2º NVMe (Netac NE-1TB, nvme0n1)

- **É um Windows 11 vivo** (Windows/, Users/, XboxGames/, Riot Games/, ~440GB usados) — mas o usuário **abandonou esse Windows** porque "travava demais com jogos".
- **SMART (via udisks/D-Bus):** desgaste 13%, spare 81% (19% consumido), ~53TB escritos, 18.160h ligado, **50 erros de mídia**, 48.279 entradas no log de erros, 452 desligamentos inseguros, **170min acima de 90°C + 10min acima de 95°C** (throttling severo; rodou sem dissipador).
- **Diagnóstico dos travamentos do Windows:** não era o Windows — era o drive: DRAM-less QLC engasgando com cache SLC cheio + throttling térmico até o limite crítico.
- **Veredito original (12/jul):** utilizável como cobaia do NixOS, inaceitável para dados únicos.
- **ATUALIZAÇÃO 13/jul — o drive está morrendo ativamente:** no primeiro boot do dia não enumerou a tempo → systemd timeout → **emergency mode** (fstab montava `/mnt/win_disk` sem `nofail`). No boot seguinte enumerou, mas minutos depois um comando admin (Get Log Page/SMART) travou o firmware → kernel tentou reset → falhou → **"Disabling device after reset failure"** — controlador desabilitado, disco virou zumbi (lsblk 0B, mount ntfs-3g órfão cuspindo Buffer I/O errors). Trajetória em 24h: lentidão → setores mortos → falha de enumeração → travamento de controlador. **Este disco NÃO serve mais nem como cobaia do NixOS** (variante A cancelada).
- Existem também: sda (HD 320GB ntfs antigo) e sdb (SanDisk 1TB SATA, aparenta ter Windows antigo — partição SYSTEM + entrada de boot órfã).

## 8. Ações já executadas (2026-07-12)

- **`minecraft-server/` movido** do disco Windows para `~/Downloads/minecraft-server/1.21.10/` (1.2GB: mundo "lariussa" + nether/end, plugins, mods, docker-compose, `.git`). Origem removida. Duas baixas em setores fisicamente mortos (I/O error persistente), ambas no `lariussa-backup/` e **sem impacto** — o mundo vivo tem versões mais novas e íntegras dos dois arquivos (`entities/r.-1.-1.mca` e o datapack "Hostile Mobs Improve Over Time.zip").
- **Health check completo** do Netac (tabela acima) via `udisksctl`/`busctl` (smartctl exigia senha sudo interativa).

## 9½. PIVÔ DE ESTRATÉGIA (13/jul, noite) — reescrita do zero na branch `nixos`

**Decisão do usuário, supersede §5 (branch) e §6 (faseamento):** aprender NixOS escrevendo a config **do zero**, direto na ISO minimal (26.05 — <https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso>), instalada **bare metal num disco secundário** (sda HD 320G ou sdb SanDisk 1TB — conferir/limpar o sdb antes, tem restos de Windows antigo; Netac descartado, está morto). Trialboot Windows+Arch+NixOS via rEFInd: **bootloader do NixOS na ESP do próprio disco secundário**, nunca na ESP do Kingston.

- **Branch `nixos`** = lar deste documento + esqueleto flake **testado** (flake check verde, VM bootou Hyprland). O esqueleto vira *gabarito de consulta* quando travar — greetd/tuigreet, bluetooth, home-manager consumindo os dirs stow, tudo já resolvido lá. **Main = Arch puro, zero nix** (commits removidos via rebase).
- O rice continua sendo reaproveitado como arquivos (ninguém reescreve QML do zero); a curadoria "do zero" vale pra camada de **sistema e pacotes**.
- Sincronização: `git merge main` periódico na `nixos` (arquivos nix não existem na main, não conflitam).
- Primeiras declarações no `configuration.nix` pra não ficar cego/incomunicável: `networking.networkmanager.enable`, **`services.openssh.enable`** (permite configurar o NixOS confortavelmente via SSH a partir do Arch), `git`, editor, usuário com senha.
- Continuam válidos deste doc: arquitetura distrobox (§3), tabela de atritos/antídotos (§4), pegadinhas de flake-em-repo (§5), regra capacidade-vs-estado, cutover final no Kingston (§6 item 4).

## 9. Pendências (reordenadas em 13/jul pela urgência)

1. ✅ **Resgate do `ResgateArch/` — CONCLUÍDO (13/jul):** 27G salvos em `~/ResgateArch/` no Kingston: `.ssh/`, `.gnupg/`, `.google_authenticator`, históricos, `Projects/` completo (21G + study/ 3G — todo código-fonte intacto), `.minecraft` (1.2G) e `Videos/` (2.3G, só um filme baixado). **Perda real: ZERO** — os 381 ilegíveis eram todos node_modules/venv/cache. Lição operacional que destravou a 3ª janela: `systemctl stop udisks2` antes de ler o disco (o polling SMART do udisks — Get Log Page a cada ~8min — era o gatilho das quedas do controlador). Decisão: perfis de navegador antigos (.mozilla/.zen) dispensados. Falta só a triagem fina do que foi salvo, no ritmo do usuário.
2. **Corrigir fstab** do Arch: linha do `/mnt/win_disk` sem `nofail` = roleta de emergency mode a cada boot. Adicionar `nofail,x-systemd.device-timeout=10s` (ou comentar a linha de vez).
3. **Esqueleto do flake** no repo (flake.nix + host de teste + home-manager) — primeiro entregável concreto.
4. ~~Decidir disco de staging~~ → decidido: comprar NVMe novo pro slot do Netac (aposentadoria do Netac após o resgate).
5. Chaves SSH/GPG antigas do ResgateArch: revisar se ainda estão autorizadas em algum lugar (higiene de segurança).
