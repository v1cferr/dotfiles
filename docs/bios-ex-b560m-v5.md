# BIOS — ASUS EX-B560M-V5 (estado desejado)

As configurações de BIOS desta placa **não são declaráveis** pelo NixOS: elas vivem
na NVRAM do firmware, e a interface do kernel `firmware-attributes` (usada pelo
`fwupdmgr get-bios-settings`) só existe em placas business Dell/Lenovo/HP — ASUS de
consumo não. O `fwupd` aqui responde literalmente `This system doesn't support
firmware settings`.

Logo, este arquivo é a forma "declarativa" possível: **a intenção versionada**. Não
aplica sozinho, mas sobrevive a Clear CMOS e é reproduzível à mão em ~2 min.

Máquina: Intel i5-11400 + Arc B580 (Battlemage). BIOS **2803** (2025/12/26).

## Settings

Acesso: `Del` no POST → `F7` (Advanced Mode).

| Setting | Valor | Onde | Status |
| --- | --- | --- | --- |
| Launch CSM | Disabled | Boot → CSM | ✅ confirmado (SO) |
| Above 4G Decoding | Enabled | Advanced → PCI Subsystem | ✅ confirmado (SO) |
| Re-Size BAR Support | Enabled | Advanced → PCI Subsystem | ✅ confirmado (SO) |
| Primary Display | PCIE | Advanced → System Agent / Graphics | ⚠️ recomendado |
| Secure Boot → OS Type | Other OS | Boot → Secure Boot | ⚠️ recomendado |
| Fast Boot | Disabled | Boot | ⚠️ recomendado |
| Ai Overclock Tuner (XMP) | XMP I (3200 MT/s) | Ai Tweaker | ✅ confirmado (3200 MT/s) |

- **Confirmado (SO):** medido pelo Linux — CSM off (a Arc é UEFI-only e bootou),
  Above 4G + ReBAR ativos (BAR de VRAM de 16G mapeada acima de 4G via `lspci`).
- **Recomendado:** boa prática pra Arc; não verificado, confirmar na próxima visita.
- **XMP:** o kit TeamGroup UD4-3200 estava rodando a 2400 MT/s (XMP desligado);
  ligado o XMP → confirmado **3200 MT/s** (`dmidecode -t 17`).

## Por que CSM = Disabled é crítico

As GPUs Arc **não têm VBIOS legacy** (são UEFI-only). Com CSM ligado, a placa-mãe
tenta inicializar o vídeo no modo legado, não acha ROM na placa e **trava no logo
ASUS**. Era o "CSM Forced Enablement Phenomenon" documentado no fórum da Intel — não
é defeito da placa.

**Raiz do problema nesta placa:** a EX-B560M-V5 tinha um default que **re-habilitava
o CSM automaticamente** (o CSM voltava sozinho após reboot/POST falho). Esse default
foi **desligado** — é o conserto de verdade, na origem. Com o CSM desligado e esse
auto-enable off, **dá pra entrar na BIOS normalmente com a Arc instalada** (o vídeo
sobe pelo GOP da placa, sem tela bugada). O `reboot=pci` (lado SO) fica como reforço.

> TODO: anotar aqui o nome exato da opção de auto-CSM que foi desligada (label na
> BIOS), pra reprodução precisa após um Clear CMOS.

## Lado do SO (isso sim é declarativo)

- `boot.kernelParams = [ "reboot=pci" ]` em `system/gpu.nix` (perfil intel): força
  reset completo via 0xCF9 no `reboot`, a GPU re-inicializa limpa como num cold boot
  e o POST não falha → o CSM nunca é religado. **Resolve o travamento no warm reboot.**
- `services.fwupd.enable = true` em `system/hardware.nix`: NÃO cobre a BIOS desta
  placa (ASUS fora do LVFS); serve p/ firmware de SSD e outros componentes.

## Backup / restauração

- **Perfil na BIOS (nativo):** Tool → ASUS User Profile (ou Save & Exit → Save
  Profile) → salva num slot (1-8) na NVRAM. Se der Clear CMOS, é só Load Profile.
- **Recuperação de travamento:** power-button ~8s → cold boot sempre recupera a Arc.
  Em último caso, Clear CMOS (jumper CLRTC ou tira a pilha ~1 min) volta ao default.

## NÃO fazer

- **NÃO flashar BIOS modificada** (mod de menus escondidos): esta placa **não tem USB
  BIOS FlashBack**, então um brick vira caso de programador SPI externo (CH341A + clip).
- **NÃO editar as variáveis cruas** (`AMITSESetup`, `CpuSetup`… via `setup_var`/
  `efivarfs` por offset): offsets indocumentados que mudam por versão de BIOS → risco
  de corromper/bricar. As opções que interessam já estão no F7 Advanced Mode.

## Atualizar a BIOS (referência)

1. Baixar o `.CAP` da versão em <https://www.asus.com/motherboards-components/motherboards/expedition/ex-b560m-v5/helpdesk_bios/>
   e conferir o SHA-256 oficial.
2. Pendrive **FAT32**, `.CAP` na raiz.
3. `Del` → `F7` → Tool → **ASUS EZ Flash 3 Utility** → seleciona o arquivo.
4. O flash **reseta as settings pro default** → reaplicar a tabela acima depois.
