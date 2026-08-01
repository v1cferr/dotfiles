# Instalação do Windows 11 no SanDisk

Runbook para instalar o Windows 11 25H2 no **SanDisk SSD PLUS 1TB**, com o Kingston
(NixOS) fisicamente conectado e **sem deixar o instalador tocar nele**.
Escrito em 01/08/2026.

> **Este arquivo tem prazo de validade.** Depois que o Windows estiver instalado e
> bootando, apague-o. Runbook desatualizado é pior que runbook nenhum.

**A rede de segurança:** o NixOS mora no Kingston, num disco separado, e o único disco
que este roteiro apaga é o SanDisk — que hoje não tem nada exclusivo (o `/home` foi
copiado byte a byte para o Kingston e conferido). O pior caso realista é o Windows se
colocar como primeiro no menu de boot, o que se resolve na BIOS em 10 segundos.

---

## A regra que importa

Só existe **um** jeito de estragar esta noite: apagar o disco errado. Os dois têm
tamanho parecido.

| Disco | `list disk` mostra | O que é |
| --- | --- | --- |
| Seagate ST9320423AS | **298 GB** | backups restic — **NÃO TOCAR** |
| **SanDisk SSD PLUS** | **931 GB** | ← o alvo |
| Kingston KC3000 | **953 GB** | NixOS — **NÃO TOCAR** |

931 e 953 se confundem num console às pressas. Por isso o roteiro obriga um
`detail disk` antes de qualquer comando destrutivo: **o nome do modelo não engana.**

---

## Como não digitar tudo

O Windows PE não lê btrfs, então este arquivo **não** estará acessível a partir do
Kingston durante a instalação. Leve uma cópia no pendrive (Fase 0.3) e, lá dentro:

```text
Shift+F10                    → abre o cmd
notepad D:\INSTALACAO-WINDOWS.md
```

A letra do pendrive varia — teste `D:`, `E:`, `F:`. No notepad você seleciona o
comando, `Ctrl+C`, e no cmd **clica com o botão direito** para colar.

---

## Fase 0 — Antes de reiniciar (no NixOS, agora)

### 0.1 Trocar a senha no autounattend

O modelo está em [`scripts/autounattend.xml`](scripts/autounattend.xml), com um
placeholder no lugar da senha.

⚠️ **Não edite o arquivo do repo.** Este repo é **público** no GitHub, e a senha fica
em texto puro no XML — é como o formato exige. Trabalhe numa cópia fora do git:

```bash
cp ~/Projects/GitHub/v1cferr/dotfiles/scripts/autounattend.xml /tmp/autounattend.xml
nano /tmp/autounattend.xml     # troque TROQUE-ESTA-SENHA pela senha real
```

### 0.2 Copiar o autounattend pro pendrive

```bash
sudo cp /tmp/autounattend.xml /mnt/usb/autounattend.xml
```

Tem que ficar na **raiz** e com esse nome exato — é onde o setup procura sozinho.

### 0.3 Copiar este guia pro pendrive

```bash
sudo cp ~/Projects/GitHub/v1cferr/dotfiles/INSTALACAO-WINDOWS.md /mnt/usb/
```

### 0.4 Desmontar

```bash
sync && sudo umount /mnt/iso /mnt/usb && echo "PENDRIVE PRONTO"
```

---

## Fase 1 — BIOS

Reinicie e entre no setup (**DEL** na EX-B560M-V5).

1. **Ativar o TPM por firmware** — o Windows 11 exige TPM 2.0:
   *Advanced → PCH-FW Configuration → TPM Device Selection → **PTT***
2. **Secure Boot ligado** — o pendrive só tem binários assinados pela Microsoft,
   então funciona com ele ativo. É o motivo de termos dividido o WIM em vez de usar
   Ventoy ou NTFS+shim.
3. Salvar e sair (**F10**).

> Se mesmo assim o instalador reclamar de "This PC can't run Windows 11", as chaves de
> bypass do `autounattend.xml` cobrem — mas prefira o PTT ligado de verdade.

---

## Fase 2 — Bootar o pendrive

**F8** no POST → escolha o pendrive em modo **UEFI** (não Legacy/CSM).

Na primeira tela do setup, **antes de clicar em qualquer coisa**: `Shift+F10`.

---

## Fase 3 — Particionar à mão ⚠️ DESTRUTIVO

Este é o passo que protege o Kingston. Criando a ESP no SanDisk **antes**, o Windows
instala o bootloader nela em vez de procurar uma existente em outro disco.

```text
diskpart
list disk
```

Anote qual número é o de **931 GB**. Então:

```text
select disk N
detail disk
```

### ⛔ PARE E LEIA A SAÍDA

O `detail disk` mostra o **modelo**. Só continue se aparecer **SanDisk SSD PLUS**.

- Se disser `KINGSTON SKC3000` → disco errado. Volte ao `select disk`.
- Se disser `ST9320423AS` → é o Seagate dos backups. Volte ao `select disk`.

Confirmado que é o SanDisk:

```text
clean
convert gpt
create partition efi size=300
format quick fs=fat32 label="System"
create partition msr size=16
create partition primary
format quick fs=ntfs label="Windows"
list partition
exit
```

O `list partition` deve mostrar três: System (300 MB), Reservada (16 MB) e a Primária
com o resto (~930 GB).

---

## Fase 4 — Instalar

De volta à GUI do setup:

1. **Edição** — escolha a que você tem licença (Pro, provavelmente). O
   `autounattend.xml` de propósito não fixa a chave, então esta tela aparece.
2. **Tipo de instalação** — *Custom: Install Windows only (advanced)*.
3. **Onde instalar** — selecione a partição **`Windows`** (~930 GB) no disco que você
   preparou. **Não** clique em Novo/Formatar/Excluir aqui; já está tudo pronto.
   - Confira que a linha selecionada é do mesmo disco da Fase 3. O setup mostra
     "Drive 0/1/2 Partition N" — o número do drive tem que bater com o `N` que você
     usou no `select disk`.

Daqui pra frente é automático: o `autounattend.xml` aceita a EULA, põe teclado ABNT2,
fuso de Brasília, cria a conta local `v1cferr` como administrador e pula as telas de
conta Microsoft e de telemetria.

---

## Fase 5 — Depois de instalar

### 5.1 Apagar o autounattend do pendrive

Ele tem sua senha em texto puro.

```text
del D:\autounattend.xml
del D:\INSTALACAO-WINDOWS.md
```

(ou espete o pendrive no NixOS depois e apague de lá)

### 5.2 Ordem de boot

O Windows provavelmente se colocou como primeira opção. Isso é normal e **não tocou em
nenhum arquivo do Kingston** — a ESP dele é a do SanDisk.

Para voltar ao NixOS: **F8** no POST e escolher o Kingston. Para tornar permanente:
*BIOS → Boot → Boot Option Priorities → #1 = Kingston*.

### 5.3 De volta no NixOS

O UUID do SanDisk mudou (ele foi reformatado), então o mount transitório passou a
mentir. Remova o bloco `/mnt/sandisk-old` de
[`hosts/nixos-kingston/default.nix`](hosts/nixos-kingston/default.nix) e rode
`rebuild`.

Enquanto não remover, o boot só emite um aviso — o `nofail` evita que ele trave.

---

## Se der errado

| Sintoma | Causa provável |
| --- | --- |
| "This PC can't run Windows 11" | PTT desligado na BIOS (Fase 1) |
| Setup não acha disco nenhum | Disco em modo RAID/Intel RST — mude para **AHCI** na BIOS |
| Instalou mas o NixOS sumiu do boot | Só a ordem da NVRAM. **F8** → Kingston. Se o Kingston não aparecer nem no F8, veja abaixo |
| Kingston não aparece no F8 | O Windows sobrescreveu a ESP dele. Boote um live USB do NixOS e rode `bootctl --esp-path=/mnt/boot install` com a raiz montada |
| Windows instalado no disco errado | Aconteceu porque o `detail disk` foi pulado. O NixOS está nos backups (Seagate + Drive) — refaça o cutover pelo `MIGRACAO-KINGSTON.md` |

**O NixOS não depende do SanDisk para nada.** Ele boota do Kingston, com sua própria
ESP em `nvme0n1p1`. O pior caso desta noite é ter que reordenar o menu de boot.
