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

## 8. Windows — tudo num passo só: `wake-fai.bat`

Equivalente Windows do `wake-fai` do Linux. Num duplo-clique ele faz, em sequência:

```text
1. conecta na VPN da FAI (SonicWall, via NECLI — o CLI do NetExtender), se não estiver;
2. se a workstation não responde no SSH, manda o Wake-on-LAN (3x) e espera ela ligar;
3. abre o `ssh superintendencia@200.136.209.229` (a senha do SSH você digita no prompt);
4. ao sair do SSH, pergunta se quer desconectar a VPN.
```

A **senha da VPN** fica guardada **criptografada** (DPAPI — só o seu usuário Windows,
nesta máquina, consegue ler). Você digita uma vez; depois conecta sem pedir nada.

### 8.1. O que você precisa ter instalado (uma vez)

1. **SonicWall NetExtender para Windows** — o app inclui o `NECLI.exe`, que o script
   usa pra conectar a VPN. Download:
   <https://www.sonicwall.com/products/remote-access/vpn-clients/>
   - Abra o NetExtender **gráfico uma vez** e conecte na VPN da FAI manualmente
     (servidor `200.133.233.101:4433`, domínio `fai2008`, seu usuário e senha). Isso
     serve só pra **aceitar o certificado** do servidor — depois o script faz tudo sozinho.
2. **Cliente SSH** — já vem por padrão no Windows 10/11 (`ssh.exe`). Pra conferir, abra
   o **PowerShell** e rode `ssh`; se aparecer a ajuda do comando, está OK.

### 8.2. Os arquivos

Copie estes **dois arquivos** (da pasta `netextender/wake-on-lan/`) pra qualquer pasta
da sua máquina — por exemplo a Área de Trabalho. Eles têm que ficar **juntos**:

- `wake-fai.bat` ← é o que você dá duplo-clique
- `wake-fai.ps1` ← o script de verdade (o `.bat` chama ele)

### 8.3. Usando (a cada vez que quiser acessar a workstation de casa)

1. **Duplo-clique no `wake-fai.bat`.**
   - O Windows pode mostrar um aviso azul (**SmartScreen**) por ser um script baixado:
     clique em **Mais informações → Executar assim mesmo**.
2. **Na 1ª vez**, ele pede o **seu usuário e senha da VPN da FAI** (uma janelinha de
   login). Isso fica salvo cifrado em `%USERPROFILE%\.wake-fai\fai-vpn.cred.xml` —
   nas próximas vezes ele nem pergunta.
3. Ele conecta a VPN, acorda a workstation (se estiver desligada, espera ~1-2 min) e
   abre o SSH. **Digite a senha do SSH** quando pedir (`superintendencia` → `Fai@sup2026`).
4. Quando terminar, **digite `exit`** no SSH. Ele pergunta se desconecta a VPN — responda
   `Y` (sim) ou `n` (manter conectada).

### 8.4. Opções (pra quem usa pelo PowerShell)

```powershell
.\wake-fai.ps1            # fluxo completo (pergunta se desconecta ao sair)
.\wake-fai.ps1 -KeepVpn   # mantém a VPN conectada ao sair do SSH
.\wake-fai.ps1 -NoSsh     # só conecta a VPN e acorda a máquina (não abre SSH)
.\wake-fai.ps1 -Reconfigure          # troca o usuário/senha da VPN salvos
.\wake-fai.ps1 -NecliPath "C:\Program Files\SonicWall\NetExtender\NECLI.exe"  # apontar o NECLI na mão
```

> O `.bat` aceita as mesmas opções: `wake-fai.bat -KeepVpn`, `wake-fai.bat -Reconfigure`, etc.

### 8.5. Problemas comuns

| Sintoma                                          | Causa provável                          | Solução                                                                                              |
| ------------------------------------------------ | --------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `NECLI.exe não encontrado`                       | NetExtender não instalado ou em local incomum | Instale o NetExtender (8.1); ou rode `.\wake-fai.ps1 -NecliPath "caminho\NECLI.exe"`             |
| VPN não conecta / erro de **certificado**        | Certificado do servidor não foi aceito  | Abra o NetExtender **gráfico** uma vez e conecte na mão pra aceitar o certificado (8.1)               |
| VPN não conecta / **usuário ou senha**           | Credencial errada                       | Rode `.\wake-fai.ps1 -Reconfigure` e digite de novo                                                  |
| A máquina não liga (não sobe em ~2 min)          | WoL/BIOS, ou pacote não chegou          | Repita (ela manda 3x); veja as seções 1-6 deste README (config do servidor / rede)                   |
| SmartScreen bloqueia o `.bat`                    | Script baixado da internet              | **Mais informações → Executar assim mesmo** (é esperado)                                              |
| VPN conecta mas o NECLI usa outra sintaxe        | Versão diferente do NetExtender         | Rode `NECLI help connect` no PowerShell e ajuste o bloco `Connect-Vpn` no `.ps1`                      |

> **Endpoint da VPN já embutido** no script (não é segredo de ninguém): servidor
> `200.133.233.101:4433`, domínio `fai2008`. **Usuário e senha da VPN são os SEUS** —
> nada vem pré-preenchido.

---

## Arquivos desta pasta

- `README.md` — este documento.
- `send-wol.exe` — enviador de magic packet para Windows (duplo-clique; `send-wol.ps1` compilado).
- `send-wol.ps1` — enviador de magic packet para Windows (PowerShell), e fonte do `.exe`.
- `send-wol.sh` — enviador de magic packet para Linux/Arch (bash puro, via `/dev/udp`); use de casa pela VPN.
- `wake-fai.ps1` — **Windows**: VPN da FAI → WoL → SSH num passo só; senha cifrada (DPAPI). Porte do `wake-fai` do Linux.
- `wake-fai.bat` — atalho de duplo-clique para o `wake-fai.ps1` (roda sem mexer na ExecutionPolicy).
