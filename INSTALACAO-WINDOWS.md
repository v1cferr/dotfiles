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

**Como o Kingston fica protegido sem desparafusar nada:** a **Fase 3** coloca os
outros discos *offline* pelo `diskpart`. O Windows não consegue escrever num disco
offline — o efeito é o mesmo de desconectar o cabo, e volta sozinho no próximo boot.

---

## 📋 Contexto para quem for ajudar a diagnosticar

> Cole esta seção (ou o link deste arquivo) para alguém que chega sem histórico.
> Tudo abaixo foi **verificado na máquina em 01/08/2026**, não é suposição.

### Hardware

| | |
| --- | --- |
| CPU | Intel Core i5-11400 (11ª gen, LGA1200) |
| Placa-mãe | ASUS EX-B560M-V5, BIOS **2803** (12/09/2025) |
| RAM | 16 GB DDR4 |
| GPU | Intel Arc B580 (Battlemage G21) |
| Fonte | Sharkoon WPM Gold Zero 550W |

### Estado da BIOS — conferido pelo Linux

| | |
| --- | --- |
| **Secure Boot** | ❌ **DESABILITADO** (a Fase 1 manda ligar — não está) |
| TPM | ✅ presente (`/dev/tpm0` existe → o PTT foi ativado) |
| Modo SATA | ⚠️ **não verificado** — se for RAID/Intel RST em vez de AHCI, é candidato |

### Discos (`fdisk -l`, 01/08)

⚠️ **As letras `/dev/sdX` EMBARALHAM entre boots** — já mudaram duas vezes nesta
máquina. Sempre confirmar pelo modelo antes de qualquer comando destrutivo, e usar
`/dev/disk/by-id/` em vez da letra.

```text
nvme0n1  953,9 GB  KINGSTON SKC3000S1024G  → NixOS (btrfs). NÃO TOCAR
sda      931,5 GB  SanDisk SSD PLUS        → alvo do Windows
sdb      298,1 GB  ST9320423AS (Seagate)   → backups restic. NÃO TOCAR
sdc       14,5 GB  v165w                   → pendrive da instalação
```

**O SanDisk já tem partições criadas pelo próprio Setup do Windows:**

```text
sda1    200M  EFI System              ← 200M é o padrão do Setup (o manual era 300M)
sda2     16M  Microsoft reserved
sda3  931,3G  Microsoft basic data
```

Isso prova que o instalador chegou a particionar e começar a aplicar a imagem.

### Mídia

- ISO: **`Win11_25H2_English_x64_v2.iso`** — baixada do site oficial da Microsoft
- Pendrive gravado com `woeusb 0.2.12`, NTFS, `install.wim` **inteiro** (7,9 GB,
  sem dividir em `.swm`), mais a partição FAT16 de 1 MB com o UEFI:NTFS do Rufus
- Instalação **padrão**, sem `autounattend.xml`

### Sintoma atual

Diálogo genérico **"Windows 11 installation has failed"**, depois da cópia dos
arquivos. O `setuperr.log` ainda **não foi lido** — é a próxima coisa a fazer.

### ✅ Já descartado (não sugerir de novo)

| Hipótese | Por que está descartada |
| --- | --- |
| Pendrive mal gravado | Chegou a copiar 7,9 GB e o Setup particionou o disco |
| `install.wim` dividido (`.swm`) | Vai inteiro nesta mídia |
| Typecode da partição do pendrive | `0700` (Microsoft basic data), correto |
| ISO adulterada / de terceiros | Trocada pela oficial da Microsoft; o erro mudou de tipo |
| `autounattend.xml` | Removido, o erro persistiu |
| Seleção/layout de partição | Passou dessa tela; o Setup criou o layout dele |
| TPM ausente | `/dev/tpm0` existe |
| Outros discos confundindo o Setup | Seagate e Kingston ficam **offline** via `diskpart` (Fase 3) |

### ❓ Ainda não investigado

1. **O `setuperr.log`** — o código do erro. É o que falta e vale mais que tudo acima
2. **Secure Boot desligado** — o Windows 11 exige; ligar antes da próxima tentativa
3. **Modo SATA na BIOS** — confirmar AHCI (não RAID / Intel RST)
4. Periféricos USB não-essenciais conectados durante a instalação

### Histórico: 5 tentativas, todas falharam

| # | Mídia | Erro |
| --- | --- | --- |
| 1 | FAT32 + `.swm`, partição `EF00` | *"A media driver your computer needs is missing"* |
| 2 | idem, partições criadas à mão | *"There is an error selecting this partition for install"* |
| 3 | idem + `clean` + Setup particionando | mesmo erro |
| 4 | idem + outros discos offline | mesmo erro |
| 5 | **woeusb NTFS + ISO oficial** | *"Windows 11 installation has failed"* ← passou muito mais longe |

---

## A regra que importa

Só existe **um** jeito de estragar esta noite: apagar o disco errado. Os dois têm
tamanho parecido.

| `list disk` | Tamanho | Disco | |
| --- | --- | --- | --- |
| **Disk 0** | 298 GB | Seagate ST9320423AS | backups restic — **NÃO TOCAR** |
| **Disk 1** | **931 GB** | **SanDisk SSD PLUS** | ← o alvo |
| **Disk 2** | 953 GB | Kingston KC3000 | NixOS — **NÃO TOCAR** |
| **Disk 3** | 14,5 GB | o pendrive | a mídia de instalação |

> A numeração acima foi **observada na prática em 01/08/2026**. Mesmo assim, confirme
> pelo tamanho — o Windows enumera por conta própria e isso pode mudar se você trocar
> algo de porta.

931 e 953 se confundem num console às pressas. Por isso o roteiro obriga um
`detail disk` antes de qualquer comando destrutivo: **o nome do modelo não engana.**

---

## Como não digitar tudo

O Windows PE não lê btrfs, então este arquivo **não** estará acessível a partir do
Kingston durante a instalação. Leve uma cópia no pendrive (Fase 0.2) e, lá dentro:

```text
Shift+F10                    → abre o cmd
notepad D:\INSTALACAO-WINDOWS.md
```

A letra do pendrive varia — teste `D:`, `E:`, `F:`. No notepad você seleciona o
comando, `Ctrl+C`, e no cmd **clica com o botão direito** para colar.

---

## Fase 0 — Antes de reiniciar (no NixOS, agora)

### 0.1 Gravar o pendrive

Um comando, no **Apêndice** no fim deste arquivo. Leva ~30 min.

### 0.2 Conferir o pendrive e copiar este guia

Verifica que o `install.wim` foi inteiro — foi o que derrubou a 3ª tentativa:

```bash
sudo mkdir -p /mnt/usb && sudo mount /dev/sdc1 /mnt/usb

ls -lh /mnt/usb/sources/install.wim          # UM arquivo de ~7,9 G
ls /mnt/usb/sources/*.swm 2>/dev/null && echo "⚠️ TEM SWM — regrave" || echo "✓ sem .swm"
ls -l /mnt/usb/efi/boot/bootx64.efi          # o boot UEFI

sudo cp ~/Projects/GitHub/v1cferr/dotfiles/INSTALACAO-WINDOWS.md /mnt/usb/
sync && sudo umount /mnt/usb && echo "PENDRIVE PRONTO"
```

> **Instalação PADRÃO, sem `autounattend.xml`.** É a decisão de 01/08 — depois de três
> falhas, quanto menos variável melhor. A consequência é que você passa pelas telas do
> OOBE à mão, incluindo o truque da conta local (Fase 6.1). O answer file continua
> disponível em [`scripts/autounattend.xml`](scripts/autounattend.xml) se um dia quiser
> automatizar; ele foi descartado como causa dos erros, não é defeituoso.

---

## Fase 1 — BIOS

Reinicie e entre no setup (**DEL** na EX-B560M-V5).

1. **Ativar o TPM por firmware** — o Windows 11 exige TPM 2.0:
   *Advanced → PCH-FW Configuration → TPM Device Selection → **PTT***
2. **Secure Boot ligado** — o bootloader UEFI:NTFS que o `woeusb` grava é assinado
   pela Microsoft (desde o Rufus 3.17), então o pendrive boota com Secure Boot ativo.
3. Salvar e sair (**F10**).

⚠️ **Sem o `autounattend.xml`, o PTT não é opcional.** Ele é que traria as chaves de
bypass do check de hardware. Numa instalação padrão o Windows 11 verifica TPM 2.0 de
verdade — se o PTT estiver desligado, o setup para em *"This PC can't run
Windows 11"* e você volta pra BIOS.

---

## Fase 2 — Bootar o pendrive

**F8** no POST → escolha o pendrive em modo **UEFI** (não Legacy/CSM).

Na primeira tela do setup, **antes de clicar em qualquer coisa**: `Shift+F10`.

---

## Fase 3 — Isolar os outros discos ⚠️ É AQUI QUE O KINGSTON FICA PROTEGIDO

**Substitui "desconectar o Kingston fisicamente"** — mesmo efeito, sem chave de fenda,
e reversível. O Windows **não consegue escrever num disco offline**.

`Shift+F10` na primeira tela do Setup:

```text
diskpart
list disk
```

Identifique pelos tamanhos: **298 GB** (Seagate) e **953 GB** (Kingston) saem de cena;
**931 GB** (SanDisk) é o alvo e **fica online**. Confirme cada um antes de tirar:

```text
select disk 0
detail disk
```

Só rode `offline disk` se o modelo bater com o que você espera tirar. Repita para o
outro:

```text
offline disk
select disk 2
detail disk
offline disk
list disk
```

O `list disk` final tem que mostrar **Offline** no Disk 0 e no Disk 2, e **Online** no
Disk 1 e no Disk 3 (pendrive).

⚠️ **Nunca** coloque offline o disco de 931 GB (é o alvo) nem o pendrive (é a mídia de
onde você está rodando).

> `offline` é estado do Windows, não toca em nada gravado. O Linux ignora
> completamente, e os discos voltam sozinhos no próximo boot.

---

## Fase 4 — Limpar o alvo e deixar o Setup particionar ⚠️ DESTRUTIVO

**NÃO crie as partições à mão.** Uma versão anterior deste guia mandava criar
ESP + MSR + NTFS pelo `diskpart`, e o Setup **recusou** com *"There is an error
selecting this partition for install"* — mesmo com o layout correto e os outros discos
já offline. O instalador do Windows 11 24H2+ implica com partição que não foi ele que
criou.

Como a Fase 3 já deixou o Kingston inalcançável, não há mais motivo para o layout
manual: o Setup **só tem um disco onde criar a ESP**. A proteção vem do `offline`, não
do particionamento.

Ainda no `diskpart`:

```text
select disk 1
detail disk
```

### ⛔ PARE E LEIA A SAÍDA

Só continue se aparecer **SanDisk SSD PLUS**.

- Se disser `KINGSTON SKC3000` → disco errado. Volte ao `select disk`.
- Se disser `ST9320423AS` → é o Seagate dos backups. Volte ao `select disk`.

Confirmado:

```text
clean
convert gpt
exit
```

O disco fica **inteiramente não alocado**. É assim que o Setup gosta.

---

## Fase 5 — Instalar

De volta à GUI do Setup, clique em **Refresh**.

1. **Edição** — escolha a que você tem licença (Pro, provavelmente). Se pedir chave de
   produto, *"I don't have a product key"* deixa escolher a edição e ativar depois.
2. **Tipo de instalação** — *Custom: Install Windows only (advanced)*.
3. **Onde instalar** — o Disk 1 deve aparecer como um único **Unallocated Space** de
   ~931,5 GB. Selecione ele e clique em **Create Partition** (ou *New*), aceitando o
   tamanho padrão.
4. O Setup cria sozinho ESP + MSR + Windows + Recovery. Selecione a **Primary** grande
   (~930 GB) e clique em **Next**.

Com os outros discos offline, ele é obrigado a pôr a ESP no Disk 1 — que era o
objetivo desde o começo, agora feito pelas ferramentas dele.

A cópia dos arquivos leva uns 10–20 min e a máquina reinicia sozinha algumas vezes.
Quando chegar no OOBE (as telas azuis de "vamos configurar seu PC"), siga a **Fase 6.1**
— é lá que está o truque da conta local.

> **Se ainda assim falhar**, o suspeito é a **mídia**, não o disco. As três falhas de
> 01/08 vieram de pendrive gravado à mão (FAT32 + WIM dividido). Confira que o
> `install.wim` está inteiro — `Shift+F10` → `dir D:\sources\install*` — e, se houver
> `.swm`, regrave com o `woeusb` (Apêndice).
>
> O `autounattend.xml` **já foi descartado** como causa: o erro persistiu sem ele.

---

## Fase 6 — Depois de instalar

### 6.1 OOBE — escapar da conta Microsoft

O Windows 11 25H2 não oferece mais a opção de conta local nas telas normais. Quando
chegar em *"Let's connect you to a network"* ou na tela de login da conta Microsoft:

```text
Shift+F10
start ms-cxh:localonly
```

Abre o diálogo clássico de criar conta local (nome + senha) e o OOBE segue dali.

> O antigo `OOBE\BYPASSNRO` foi **removido** no 24H2 — não perca tempo com ele.
> Desconectar o cabo de rede **antes** de ligar o PC também costuma fazer o OOBE
> oferecer a conta local sozinho, e é o plano B se o comando acima não pegar.

### 6.2 Tirar o guia do pendrive

```text
del D:\INSTALACAO-WINDOWS.md
```

(ou espete o pendrive no NixOS depois e apague de lá)

### 6.3 O relógio — senão os dois sistemas brigam

O NixOS guarda o **RTC em UTC** (conferido: `RTC in local TZ: no`). O Windows assume
que o RTC está em **hora local**. Sem corrigir, cada troca de sistema move o relógio
em 3 horas, e você fica reajustando pra sempre.

A correção certa é ensinar o Windows a usar UTC — assim o padrão sensato do NixOS
fica intacto. Num **cmd como administrador**, no Windows:

```text
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

Reinicie e ajuste a hora uma última vez. A partir daí os dois concordam.

### 6.4 BitLocker — confira antes de confiar

A **conta local** da Fase 6.1 já evita o pior: a criptografia automática do Windows 11
só liga sozinha quando você entra com conta Microsoft, que é quem guarda a chave de
recuperação. Mesmo assim, há relatos de o 25H2 cifrar volumes em instalação limpa,
então vale checar. Num cmd como administrador:

```text
manage-bde -status
```

Se disser **"Protection On"** em algum volume, você tem duas saídas — e precisa
escolher uma **agora**, não depois:

- `manage-bde -off C:` para desligar, ou
- salvar a chave de recuperação num lugar seguro (Bitwarden)

**Por que isso importa no seu caso:** sem conta Microsoft, ninguém guardou a chave por
você. E você vai ficar alternando entradas de boot entre NixOS e Windows — mexer em
Secure Boot ou na ordem de boot pode disparar a tela de recuperação do BitLocker. Sem
a chave, o disco vira tijolo.

### 6.5 Os discos offline voltam sozinhos

O `offline disk` da Fase 3 é estado do Windows e some no reboot — Seagate e Kingston
reaparecem normalmente, tanto no Windows quanto no NixOS. Se por algum motivo o
Windows continuar mostrando algum deles como offline em *Disk Management*, clique com
o direito no disco → **Online**. Nada foi alterado no conteúdo.

### 6.6 Ordem de boot

O Windows provavelmente se colocou como primeira opção. Isso é normal e **não tocou em
nenhum arquivo do Kingston** — a ESP dele é a do SanDisk.

Para voltar ao NixOS: **F8** no POST e escolher o Kingston. Para tornar permanente:
*BIOS → Boot → Boot Option Priorities → #1 = Kingston*.

### 6.7 De volta no NixOS

O UUID do SanDisk mudou (ele foi reformatado), então o mount transitório passou a
mentir. Remova o bloco `/mnt/sandisk-old` de
[`hosts/nixos-kingston/default.nix`](hosts/nixos-kingston/default.nix) e rode
`rebuild`.

Enquanto não remover, o boot só emite um aviso — o `nofail` evita que ele trave.

---

## Se der errado

### ⭐ ANTES DE CHUTAR: leia o log

O Setup grava o motivo real num arquivo. Cada tentativa às cegas custa 30 min; ler o
log custa 2. **Faça isto primeiro.**

Na tela de erro, `Shift+F10`:

```text
notepad X:\Windows\Panther\setuperr.log
```

`X:` é o disco RAM do WinPE. Se o arquivo não existir ou estiver vazio, procure os
outros — dependendo de onde falhou, o log muda de lugar:

```text
dir /s /b X:\Windows\Panther\*.log
dir /s /b C:\$WINDOWS.~BT\Sources\Panther\*.log
dir /s /b C:\Windows\Panther\*.log
```

O que interessa são as **últimas 15–20 linhas** e qualquer código no formato
`0x8007...` / `0xC1900...` — é ele que identifica a causa. Para filtrar só os erros
sem abrir o editor:

```text
findstr /i "error fail 0x" X:\Windows\Panther\setuperr.log
```

Se precisar levar o log pra fora, copie pro pendrive (que é gravável, é NTFS):

```text
copy X:\Windows\Panther\setuperr.log D:\
```

> **Por que isto virou a primeira coisa da lista:** em 01/08 foram cinco tentativas,
> cada uma trocando uma variável por palpite — typecode, layout de partição, WIM
> dividido, answer file, ISO. Quatro dessas horas teriam sido evitadas lendo
> `setuperr.log` na primeira falha.

### Tabela de sintomas

| Sintoma | Causa provável |
| --- | --- |
| **"Windows 11 installation has failed"** (genérico, já depois de copiar arquivos) | Passou da seleção de partição — o problema NÃO é mais disco nem mídia. **Leia o `setuperr.log`** (acima); sem o código não dá pra saber |
| **"A media driver your computer needs is missing"** | Pendrive mal gravado. Regrave com **`woeusb`** (Apêndice) — não tente FAT32 + WIM dividido |
| **"There is an error selecting this partition for install"** | **Aconteceu 3× em 01/08.** Some com: pendrive feito pelo `woeusb` (NTFS, WIM inteiro) + `clean` no alvo + Setup particionando. Ver o Apêndice para o histórico das tentativas |
| `unknown filesystem type 'ntfs-3g'` ao gravar o pendrive | Falta `boot.supportedFilesystems.ntfs = true` no NixOS — já declarado em [`system/core/boot.nix`](system/core/boot.nix) |
| Partição alvo aparece como *Read-only* | `select disk 1` → `attributes disk clear readonly` |
| "This PC can't run Windows 11" | PTT desligado na BIOS (Fase 1) |
| Setup não acha disco nenhum | Disco em modo RAID/Intel RST — mude para **AHCI** na BIOS |
| Instalou mas o NixOS sumiu do boot | Só a ordem da NVRAM. **F8** → Kingston. Se o Kingston não aparecer nem no F8, veja abaixo |
| Kingston não aparece no F8 | O Windows sobrescreveu a ESP dele. Boote um live USB do NixOS e rode `bootctl --esp-path=/mnt/boot install` com a raiz montada |
| Windows instalado no disco errado | Aconteceu porque o `detail disk` foi pulado. O NixOS está nos backups (Seagate + Drive) — refaça o cutover pelo `MIGRACAO-KINGSTON.md` |

**O NixOS não depende do SanDisk para nada.** Ele boota do Kingston, com sua própria
ESP em `nvme0n1p1`. O pior caso desta noite é ter que reordenar o menu de boot.

### A lição das três falhas

Todas tiveram a mesma raiz: **tentar ser mais correto que as ferramentas do Windows.**
Typecode "mais padrão" (`EF00`), layout de partição "mais explícito", boot "mais
assinado" (FAT32 + WIM dividido). O Windows queria `0700`, queria criar as partições
dele, e nunca precisou do WIM dividido.

A combinação que funciona separa as responsabilidades por dono:

| Responsabilidade | Quem faz |
| --- | --- |
| Gravar o pendrive | `woeusb` — a ferramenta que já resolve isso |
| **Proteger o Kingston** | `offline disk` no `diskpart` (Fase 3) |
| Particionar o disco alvo | o próprio Setup do Windows |

Não tente fazer as três com a mesma ferramenta, e não tente fazer nenhuma à mão
quando existe uma que já faz.

---

## Apêndice — como gravar o pendrive

**Use o `woeusb`. Um comando.** Ele particiona, formata em NTFS, copia o
`install.wim` INTEIRO (sem dividir) e instala o bootloader UEFI:NTFS numa partição
FAT16 de 1 MB no fim do disco — o mesmo layout que o Rufus produz.

```bash
sudo umount /dev/sdc* 2>/dev/null
sudo nix shell nixpkgs#woeusb -c woeusb \
  --device ~/Downloads/en-us_windows_11_..._x64_dvd_....iso \
  /dev/sdc --target-filesystem NTFS
```

Precisa de **rede** (baixa o `uefi-ntfs.img` do repo do Rufus) e de
**`boot.supportedFilesystems.ntfs = true`** no sistema — já declarado em
[`system/core/boot.nix`](system/core/boot.nix). Sem isso ele morre com
*"unknown filesystem type 'ntfs-3g'"* logo depois de formatar.

Leva ~30 min neste pendrive (escreve a ~4 MB/s).

**Secure Boot continua ligado.** O UEFI:NTFS é assinado pela Microsoft desde o Rufus
3.17, então NTFS não custa mais o Secure Boot — que é justamente a suposição errada
que me levou pelo caminho longo abaixo.

### ⚠️ O caminho que NÃO funciona — três tentativas perdidas

Tentei FAT32 + `install.wim` dividido em `.swm` com o `wimlib`, porque o WIM do
Windows 11 tem **7,96 GB** e não cabe nos 4 GiB por arquivo do FAT32. A justificativa
era manter o boot 100% assinado pela Microsoft, para não perder o Secure Boot.

**A premissa estava obsoleta**: o UEFI:NTFS é assinado desde 2021. NTFS nunca custou
o Secure Boot. Passei por três falhas antes de perceber:

| Tentativa | Erro | Causa |
| --- | --- | --- |
| 1 | *"A media driver your computer needs is missing"* | Partição tipada `EF00` (EFI System). O Windows **não dá letra de unidade a uma ESP**, então o Setup não achava o `sources/`. O certo seria `0700` |
| 2 | *"There is an error selecting this partition for install"* | Layout de partições criado à mão no `diskpart`. O instalador 24H2+ recusa partição que não foi ele que criou |
| 3 | O mesmo erro | `clean` + Setup particionando + sem `autounattend.xml`. Sobrou o **`.swm`**: o setup do 24H2+ tem problemas conhecidos com WIM dividido |

A lição, que vale além deste guia: **quando a ferramenta oficial resolve o problema,
não invente**. Cada uma das três falhas veio de eu tentar ser mais correto que o
Windows — typecode "mais padrão", layout "mais explícito", boot "mais assinado".

### Opcional: automatizar o OOBE com `autounattend.xml`

**Não usado nesta instalação** — a de 01/08 foi padrão, para reduzir variáveis depois
das três falhas. Mas o answer file existe, está validado, e poupa as telas do OOBE
(EULA, teclado ABNT2, fuso, conta local, telas de telemetria).

Se um dia quiser usar, o modelo está em
[`scripts/autounattend.xml`](scripts/autounattend.xml):

```bash
cp ~/Projects/GitHub/v1cferr/dotfiles/scripts/autounattend.xml /tmp/autounattend.xml
nano /tmp/autounattend.xml          # troque TROQUE-ESTA-SENHA

sudo mount /dev/sdc1 /mnt/usb
sudo cp /tmp/autounattend.xml /mnt/usb/      # na RAIZ, com este nome exato
sync && sudo umount /mnt/usb
rm /tmp/autounattend.xml                     # a senha fica em texto puro
```

⚠️ **Nunca edite o arquivo do repo** — este repo é público no GitHub e a senha do XML
não é cifrada. Trabalhe sempre numa cópia fora do git, e apague depois.

> Ele foi **descartado como causa** dos erros na tentativa 3 (o problema persistiu sem
> ele), então não é defeituoso. Vantagem colateral: traz as chaves de bypass do check
> de hardware, então dispensa o PTT ligado.
