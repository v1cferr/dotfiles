# Wake-on-LAN — superintendencia-server

Documentação da configuração de Wake-on-LAN (WoL) desta workstation, para ligá-la
remotamente sem teclado/HDMI.

> Status: **configurado e validado em rede (máquina ligada)** — inclusive o caminho
> **de casa pela VPN da FAI**: magic packet confirmado chegando na `enp7s0` via tcpdump
> (origem `192.168.50.9` da VPN → `200.136.209.255`, `length 102`, 2026-06-16). E o
> teste físico com a máquina **DESLIGADA** também **passou** (2026-06-16): o `wake-fai`
> de casa acordou a workstation do S5 (uptime de 57s no primeiro boot pós-WoL).
> Última atualização: 2026-06-16.

---

## 1. Contexto da máquina

| Item                    | Valor                                                                |
| ----------------------- | -------------------------------------------------------------------- |
| Tipo                    | Workstation consumer (i9-14900K + RTX 5090), **sem BMC/iLO/IPMI**    |
| SO                      | Ubuntu 26.04 LTS                                                     |
| Interface de rede ativa | `enp7s0` (NIC PCIe — **não** a onboard `eno1`)                       |
| **MAC (alvo do WoL)**   | **`8c:86:dd:61:22:12`**                                              |
| IP (estático)           | `200.136.209.229/25` (sub-rede `200.136.209.128/25`, gateway `.241`) |
| Broadcast da sub-rede   | **`200.136.209.255`** ← mira o WoL aqui                              |

Como não há BMC, ligar a máquina remotamente depende de WoL (ou, em último caso, de
um plug inteligente — ver seção 7).

---

## 2. O que foi configurado (lado servidor) — CONCLUÍDO

1. **Netplan** — adicionado `wakeonlan: true` ao bloco `enp7s0` em
   `/etc/netplan/00-installer-config.yaml` (backup: `00-installer-config.yaml.bak-prewol`).
   Isso gera `/run/systemd/network/10-netplan-enp7s0.link` com `WakeOnLan=magic`,
   aplicado pelo **udev a cada boot** → persistente.

2. **BIOS/UEFI** — habilitado **"Power On by PCIe"** e desabilitado **"ErP/EuP Ready"**
   (ErP corta a energia de standby da placa no S5 e mataria o WoL).

3. **SSH** — `ssh` está `enabled` no boot e o IP é estático → quando a máquina acorda
   e termina de bootar, o SSH volta sozinho no mesmo endereço.

### Verificar no servidor

```bash
sudo ethtool enp7s0 | grep Wake-on
# Esperado:
#   Supports Wake-on: pg     <- a placa suporta magic packet (g)
#   Wake-on: g               <- magic packet ARMADO (persistiu após reboot ✔)
```

---

## 3. Como acordar a máquina (a partir de um Windows na rede FAI)

### Jeito mais fácil: `send-wol.exe`

Basta **dar duplo-clique** no `send-wol.exe` desta pasta (ou rodar `.\send-wol.exe`
no terminal). Já vem com o MAC e o broadcast certos; não precisa de PowerShell nem de
instalar nada. Quando aberto por duplo-clique ele pausa no final pra você ler a saída.

Para mirar outro alvo/MAC, passe os mesmos parâmetros do script:

```powershell
.\send-wol.exe -Mac "8c:86:dd:61:22:12" -Target "200.136.209.255" -Port 9
```

> O `.exe` é apenas o `send-wol.ps1` compilado (via [ps2exe](https://github.com/MScholtes/PS2EXE)).
> Para recompilar depois de editar o `.ps1`:
> `Install-Module ps2exe -Scope CurrentUser` e então
> `Invoke-ps2exe .\send-wol.ps1 .\send-wol.exe`.

### Via PowerShell / função inline

A partir de qualquer Windows na rede `FAI_COLABORADORES` (`192.168.223.0/24`),
abra o **PowerShell** e use o `send-wol.ps1` desta pasta, ou cole a função abaixo.

```powershell
function Send-WOL { param([string]$Mac,[string]$Target="255.255.255.255",[int]$Port=9)
  $m = $Mac -replace '[:\-]',''
  $macBytes = for ($i=0; $i -lt 12; $i+=2) { [Convert]::ToByte($m.Substring($i,2),16) }
  $packet = (,[byte]0xFF * 6) + ($macBytes * 16)
  $udp = New-Object System.Net.Sockets.UdpClient
  $udp.EnableBroadcast = $true
  $udp.Connect($Target,$Port); [void]$udp.Send($packet,$packet.Length); $udp.Close()
  Write-Host "Magic packet -> $Target : $Mac" }

# Disparar (use o BROADCAST da sub-rede do servidor):
Send-WOL -Mac "8c:86:dd:61:22:12" -Target "200.136.209.255"
```

> Está no Git Bash? Digite `powershell` para entrar no PowerShell antes de colar.

### Por que `200.136.209.255` e não `200.136.209.229`?

A máquina (`192.168.223.x`) e o servidor (`200.136.209.x`) estão em **sub-redes L3
diferentes**, com um roteador no meio. Foi comprovado por `tcpdump` que a rede da FAI
**repassa** o pacote pra dentro do segmento do servidor — então **não precisa do TI**.
Mas:

- **`.255` (directed broadcast)** → entregue como broadcast L2 ao segmento; a placa em
  standby recebe **sem depender de ARP**. ✅ Método confiável com a máquina desligada.
- **`.229` (unicast)** → depende do roteador ter o ARP `.229 → MAC` em cache. Com a
  máquina desligada a placa não responde ARP, o cache expira e para de funcionar.
  Só serve na janela curta logo após desligar.

### A partir do Linux / de casa pela VPN (`send-wol.sh`)

Em casa, conectado na **VPN da FAI**, use o `send-wol.sh` (Arch ou qualquer distro com
bash). Não precisa de pacote nenhum — ele usa o `/dev/udp` embutido no bash. Pela VPN,
`200.136.209.255` é apenas um IP roteável para o kernel local, então o pacote sai pelo
túnel normalmente (não exige `SO_BROADCAST`).

```bash
chmod +x send-wol.sh        # só na primeira vez
./send-wol.sh               # padrões já configurados
./send-wol.sh -n 3          # envia 3x (UDP não garante entrega; se não ligar, repita)
./send-wol.sh -t 200.136.209.255 -m 8c:86:dd:61:22:12 -p 9   # sobrescrevendo
```

> Pré-requisito: a VPN precisa estar **conectada** e rotear o segmento
> `200.136.209.128/25`. Confirme com `ip route get 200.136.209.255` (deve sair pela
> interface da VPN, ex. `tun0`/`wg0`).

---

## 4. Teste de ponta a ponta (máquina desligada)

1. No servidor: `sudo poweroff`
2. Espera ~30s (a placa entra em standby).
3. No Windows (PowerShell): `Send-WOL -Mac "8c:86:dd:61:22:12" -Target "200.136.209.255"`
4. A máquina deve ligar (ventoinha/LED). Se não ligar em ~10s, dispara mais 1-2 vezes.
5. Espera 1-2 min e conecta: `ssh 200.136.209.229`

---

## 5. Confirmação de que o pacote chega na placa (diagnóstico)

Com a **máquina ligada**, dá pra confirmar que o magic packet atravessa a rede:

```bash
# No servidor (deixe rodando):
sudo tcpdump -ni enp7s0 'udp port 9 or udp port 7 or ether proto 0x0842'
```

Dispare o `Send-WOL` do Windows. Se aparecerem linhas como
`192.168.223.79.xxxxx > 200.136.209.255.9: UDP, length 102`, o pacote está chegando
(`length 102` = tamanho exato do magic packet). Foi assim que validamos o caminho.

---

## 6. Troubleshooting

| Sintoma                                | Causa provável          | Ação                                                                            |
| -------------------------------------- | ----------------------- | ------------------------------------------------------------------------------- |
| `Wake-on:` mostra `d` (não `g`)        | Driver/persistência     | `sudo netplan generate` e reboot; conferir o `.link` em `/run/systemd/network/` |
| Pacote não aparece no tcpdump          | Roteador não repassou   | Mirar `.255` (não `.229`); se persistir, falar com o TI                         |
| Pacote chega mas a máquina não liga    | BIOS                    | Revisar "Power On by PCIe" ON e "ErP/EuP Ready" OFF; manter a máquina na tomada |
| Liga só logo após desligar, depois não | ARP do roteador expirou | Usar `.255` (broadcast), não `.229` (unicast); ou pedir ARP estático ao TI      |

> **Firewall (UFW) NÃO interfere no WoL.** Com a máquina desligada o SO não roda, logo
> não há iptables/UFW — quem detecta o magic packet é o hardware da placa. Comprovado:
> o tcpdump vê o pacote antes do netfilter.

---

## 7. Plano B (se algum dia o WoL falhar)

- **Plug Wi-Fi inteligente** + BIOS **"Restore on AC Power Loss = Power On"**: corta e
  restaura a energia pelo app do plug → a máquina liga. Ignora totalmente a rede.
- **ARP estático no roteador** (via TI): permite acordar por unicast no `.229` de
  qualquer lugar (inclusive VPN), de forma determinística.

---

## Arquivos desta pasta

- `README.md` — este documento.
- `send-wol.exe` — enviador de magic packet para Windows (duplo-clique; `send-wol.ps1` compilado).
- `send-wol.ps1` — enviador de magic packet para Windows (PowerShell), e fonte do `.exe`.
- `send-wol.sh` — enviador de magic packet para Linux/Arch (bash puro, via `/dev/udp`); use de casa pela VPN.
