<#
.SYNOPSIS
  Envia um Wake-on-LAN magic packet para o superintendencia-server.

.DESCRIPTION
  Use a partir de um Windows na rede FAI_COLABORADORES (192.168.223.0/24).
  No Git Bash, digite "powershell" antes para entrar no PowerShell.

.EXAMPLE
  # Acordar o servidor (padrão: MAC e broadcast da sub-rede já configurados):
  .\send-wol.ps1

.EXAMPLE
  # Sobrescrevendo alvo/MAC:
  .\send-wol.ps1 -Mac "8c:86:dd:61:22:12" -Target "200.136.209.255"
#>
param(
  [string]$Mac    = "8c:86:dd:61:22:12",   # MAC da enp7s0 do servidor
  [string]$Target = "200.136.209.255",     # broadcast da sub-rede 200.136.209.128/25
  [int]$Port      = 9
)

$m = $Mac -replace '[:\-]', ''
$macBytes = for ($i = 0; $i -lt 12; $i += 2) { [Convert]::ToByte($m.Substring($i, 2), 16) }
$packet = (, [byte]0xFF * 6) + ($macBytes * 16)   # 6x FF + 16x MAC = 102 bytes

$udp = New-Object System.Net.Sockets.UdpClient
$udp.EnableBroadcast = $true
$udp.Connect($Target, $Port)
[void]$udp.Send($packet, $packet.Length)
$udp.Close()

Write-Host "Magic packet enviado -> $Target (porta $Port) para $Mac"

# Pausa apenas quando aberto por duplo-clique (processo pai = explorer),
# para dar tempo de ler a saida. No PowerShell/terminal nao pausa.
try {
  $parentId = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction Stop).ParentProcessId
  if ((Get-Process -Id $parentId -ErrorAction Stop).ProcessName -eq 'explorer') {
    Read-Host "`nPressione Enter para fechar"
  }
} catch { }
