# Ligar o dualboot com Secure Boot — passo a passo

> **ARQUIVO TEMPORÁRIO.** Apagar assim que o Secure Boot estiver ligado e os dois
> sistemas bootando. O que precisa sobreviver já está no cabeçalho de
> [`system/core/secureboot.nix`](system/core/secureboot.nix) — este aqui é só a
> sequência da noite. Runbook cumprido que fica no repo vira mentira depois.

O código já está commitado e o `nixos-rebuild build` passa. **Nada foi aplicado.**

## O que pode dar errado, e por que não é grave

O NixOS boota do Kingston (`nvme0n1`) e o Windows do SanDisk (`sdb`) — ESPs
separadas, em discos separados. Nenhum passo aqui escreve no disco do outro.

O pior caso realista é a firmware recusar o GRUB por falta de assinatura, e a saída
é sempre a mesma: **desligar o Secure Boot na BIOS**. Não existe tijolo neste
roteiro; o que a firmware recusa é um binário, não o disco.

---

## Fase 0 — Windows: desligar o BitLocker ⚠️ FAÇA ISTO PRIMEIRO

O volume `sdb3` está formatado com BitLocker. Mexer em Secure Boot **muda o PCR 7**,
e o BitLocker responde a isso pedindo a chave de recuperação no boot — que ninguém
guardou, porque a conta é local.

Boote o Windows, abra um **cmd como administrador**:

```text
manage-bde -status
```

Se algum volume disser **"Protection On"**:

```text
manage-bde -off C:
```

Isso **decifra o disco** e leva de minutos a horas em 900 GB. Acompanhe com
`manage-bde -status` até `Percentage Encrypted: 0.0%` e `Protection Off`.

> ⛔ Não siga pra Fase 1 enquanto a decifragem não terminar. Reiniciar no meio não
> corrompe nada, mas a proteção continua ativa até o fim — que é justamente o
> problema.

**Já que está no Windows**, resolva também o relógio (senão os dois sistemas brigam
por 3 horas a cada troca — o NixOS guarda o RTC em UTC e o Windows assume hora local):

```text
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

---

## Fase 1 — NixOS: GRUB no ar, ainda SEM Secure Boot

O objetivo desta fase é provar que o GRUB sobe e enxerga o Windows, **enquanto
errar ainda é barato**. Não pule para o Secure Boot antes disto funcionar.

```bash
cd ~/Projects/GitHub/v1cferr/dotfiles
sudo sbctl create-keys          # cria /var/lib/sbctl/keys
rebuild
```

O `rebuild` vai imprimir `installing the GRUB 2 boot loader...`. A entrada do Windows
é **fixa por UUID** (`904C-B9D0`, a ESP do SanDisk), não vem de varredura — então ela
sempre aparece no arquivo. O que precisa ser conferido é se o UUID ainda bate:

```bash
sudo grep -A5 'menuentry "Windows 11"' /boot/grub/grub.cfg
lsblk -o NAME,LABEL,UUID /dev/sdb    # sdb1 tem que ser 904C-B9D0
sbctl verify                          # o grubx64.efi deve aparecer como assinado
```

Se o UUID do `sdb1` **não** for `904C-B9D0`, corrija em
[`system/core/boot.nix`](system/core/boot.nix) antes de seguir — a entrada existiria
no menu e simplesmente não bootaria.

**Reinicie.** Você deve ver o menu do Minecraft com dois mundos: NixOS e Windows 11.
Teste **os dois**, incluindo entrar no Windows e voltar.

---

## Fase 2 — BIOS: apagar as chaves de fábrica

Reinicie e entre no setup (**DEL** na EX-B560M-V5).

1. `Boot → Secure Boot → Key Management → **Clear Secure Boot Keys**`
2. Salvar e sair (**F10**).

Isso põe a firmware em **Setup Mode**. O boot segue normal — em Setup Mode o Secure
Boot está inativo, então o GRUB e o Windows continuam subindo.

---

## Fase 3 — NixOS: enrolar as chaves

```bash
sudo sbctl enroll-keys -m
sbctl status
```

O `status` deve mostrar **Setup Mode: Disabled** (as chaves entraram).

> ⚠️ **O `-m` não é opcional.** Ele é o que reinstala os certificados da Microsoft
> junto com os seus. Sem ele você derruba o Windows **e** a option ROM da Arc B580 —
> as duas são assinadas pela Microsoft. Já foi conferido nesta máquina: o `sbctl`
> 0.18 traz as duas gerações de CA (2011 e 2023), então o Windows continua bootando
> mesmo depois de o certificado de 2011 ter expirado, em junho/2026.

---

## Fase 4 — BIOS: ligar o Secure Boot

1. `Boot → Secure Boot → OS Type → **Windows UEFI mode**`
2. Confirme que `Secure Boot State` virou **Enabled**.
3. Salvar e sair (**F10**).

---

## Fase 5 — Conferir

No NixOS:

```bash
sbctl status                    # Secure Boot: ✓ Enabled
sbctl verify                    # grubx64.efi assinado
bootctl status | head -5        # Secure Boot: enabled
```

No Windows, `msinfo32` → **Secure Boot State: On**.

---

## Se der errado

| Sintoma | O que é |
| --- | --- |
| Firmware não boota nada / "Invalid signature" | O GRUB foi reescrito sem assinatura. **BIOS → Secure Boot: Disabled**, boote, `sudo sbctl sign -s /boot/EFI/*/grubx64.efi`, religue o SB |
| Windows no menu, mas não boota | O UUID mudou. `lsblk -o NAME,LABEL,UUID /dev/sdb` e corrija o `search --fs-uuid` em [`system/core/boot.nix`](system/core/boot.nix) |
| Windows pede chave de recuperação | O BitLocker não foi desligado (Fase 0). Sem a chave, `sbctl reset` + SB off devolve o PCR 7 anterior |
| Arc B580 sem vídeo no POST | `enroll-keys` sem o `-m`. `sudo sbctl reset` na BIOS em Setup Mode e refaça a Fase 3 **com** o `-m` |
| Menu do GRUB feio/esticado | O `gfxmodeEfi` não pegou 1080p. Ajustar em [`system/core/boot.nix`](system/core/boot.nix) |
| Ícone genérico, sem texto, em alguma entrada | O `--class` daquela entrada não casa com nenhum `customIcons.name`. Ver `grep menuentry /boot/grub/grub.cfg` |

**Recuperação de último caso:** desligar Secure Boot na BIOS devolve o boot em todos
os cenários acima. O NixOS não depende do SanDisk pra nada, e o Windows não depende
do Kingston.

---

## Depois que estiver tudo de pé

1. `git rm SECURE-BOOT-SETUP.md` — este arquivo cumpriu o papel.
2. Conferir se o Moonlight ainda pareia (o `sunshine_name` mudou de `nixos-sandisk`
   pra `nixos-kingston` — é só nome de exibição, o pareamento é por certificado).
