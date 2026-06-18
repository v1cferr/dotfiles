<#
.SYNOPSIS
  wake-fai (Windows) — conecta na VPN da FAI.UFSCAR (SonicWall/NetExtender),
  acorda a workstation via Wake-on-LAN (se estiver desligada) e abre o SSH nela.

.DESCRIPTION
  Porte fiel do `wake-fai` do Linux para Windows. Encadeia os passos manuais:
    1. VPN  -> conecta no SonicWall via NECLI (CLI do NetExtender), se ainda nao estiver;
    2. WoL  -> se a workstation nao responde na porta SSH, manda o magic packet;
    3. SSH  -> abre a sessao interativa (ssh.exe nativo do Windows 10/11);
    4. fim  -> oferece desconectar a VPN (so se fomos nos que ligamos).

  A SENHA da VPN fica salva CRIPTOGRAFADA com DPAPI (so o seu usuario Windows,
  nesta maquina, consegue ler) em %USERPROFILE%\.wake-fai\fai-vpn.cred.xml.
  Na 1a execucao ela e' solicitada; depois conecta sem pedir nada. Use
  -Reconfigure para trocar usuario/senha.

  Pre-requisitos:
    - SonicWall NetExtender instalado (o script auto-detecta o NECLI.exe).
    - Cliente OpenSSH do Windows (ssh.exe) — vem por padrao no Win10/11.

.EXAMPLE
  # Fluxo completo (VPN -> WoL -> SSH), perguntando se desconecta ao sair:
  .\wake-fai.ps1

.EXAMPLE
  # Mantem a VPN conectada ao sair do SSH (nao pergunta):
  .\wake-fai.ps1 -KeepVpn

.EXAMPLE
  # So conecta a VPN e acorda a maquina, sem abrir SSH:
  .\wake-fai.ps1 -NoSsh

.EXAMPLE
  # Regrava usuario/senha da VPN:
  .\wake-fai.ps1 -Reconfigure

.EXAMPLE
  # Aponta o NECLI manualmente (se a auto-deteccao falhar):
  .\wake-fai.ps1 -NecliPath "C:\Program Files\SonicWall\NetExtender\NECLI.exe"
#>
[CmdletBinding()]
param(
  # ---- VPN (defaults do perfil FAI.UFSCAR salvo no repo) -------------------
  [string]$Server   = "200.133.233.101:4433",
  [string]$Domain   = "fai2008",
  [string]$NecliPath,                                  # auto-detectado se vazio

  # ---- Workstation (superintendencia-server) ------------------------------
  [string]$WsIp        = "200.136.209.229",
  [string]$WsUser      = "superintendencia",          # senha do SSH e' digitada no prompt
  [int]   $WsPort      = 22,
  [string]$Mac         = "8c:86:dd:61:22:12",          # MAC da enp7s0
  [string]$WolTarget   = "200.136.209.255",            # broadcast da sub-rede /25
  [int]   $WolPort     = 9,
  [int]   $BootWait    = 150,                          # seg max esperando o boot

  # ---- Comportamento ------------------------------------------------------
  [switch]$KeepVpn,                                    # nao pergunta; mantem a VPN
  [switch]$NoSsh,                                      # pula a etapa de SSH
  [switch]$Reconfigure                                 # regrava credenciais
)

$ErrorActionPreference = "Stop"

function Info($m)  { Write-Host "→ $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "✓ $m" -ForegroundColor Green }
function Warn($m)  { Write-Host "⚠ $m" -ForegroundColor Yellow }
function Fail($m)  { Write-Host "✗ $m" -ForegroundColor Red }

# ===========================================================================
# 0) NECLI — localizar o CLI do NetExtender
# ===========================================================================
function Find-Necli {
  param([string]$Override)

  if ($Override) {
    if (Test-Path $Override) { return $Override }
    throw "NECLI nao encontrado no caminho informado: $Override"
  }

  # 1) ja' esta no PATH?
  $cmd = Get-Command "NECLI.exe" -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  # 2) caminhos conhecidos das varias versoes do NetExtender no Windows
  $candidates = @(
    "$env:ProgramFiles\SonicWall\NetExtender\NECLI.exe"
    "${env:ProgramFiles(x86)}\SonicWall\NetExtender\NECLI.exe"
    "${env:ProgramFiles(x86)}\SonicWall\SSL-VPN\NetExtender\NECLI.exe"
    "$env:ProgramFiles\Dell SonicWALL\NetExtender\NECLI.exe"
    "${env:ProgramFiles(x86)}\Dell SonicWALL\NetExtender\NECLI.exe"
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }

  # 3) varredura (mais lenta) por baixo de Program Files
  foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if (-not $root) { continue }
    $hit = Get-ChildItem -Path $root -Filter "NECLI.exe" -Recurse -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if ($hit) { return $hit.FullName }
  }

  return $null
}

# ===========================================================================
# 1) Credenciais (DPAPI — criptografadas por usuario+maquina)
# ===========================================================================
$ConfigDir = Join-Path $env:USERPROFILE ".wake-fai"
$CredPath  = Join-Path $ConfigDir "fai-vpn.cred.xml"

function Get-VpnCredential {
  param([switch]$Force)

  if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
  }

  if ($Force -or -not (Test-Path $CredPath)) {
    Write-Host ""
    Info "Configurando credenciais da VPN da FAI (salvas criptografadas nesta maquina)."
    Write-Host "  Informe SEU usuario e senha da VPN da FAI.UFSCAR."
    $cred = Get-Credential -Message "VPN FAI.UFSCAR — seu usuario e senha"
    # Export-Clixml cifra a SecureString via DPAPI (atada a este usuario+PC).
    $cred | Export-Clixml -Path $CredPath
    Ok "Credenciais salvas em $CredPath"
    return $cred
  }

  return Import-Clixml -Path $CredPath
}

# Converte a SecureString para texto puro so' no instante de chamar o NECLI.
function ConvertFrom-SecureToPlain {
  param([System.Security.SecureString]$Secure)
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
  try   { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# ===========================================================================
# 2) VPN — status / connect / disconnect via NECLI
# ===========================================================================
function Invoke-Necli {
  param([string[]]$NecliArgs)
  # Captura stdout+stderr; devolve as linhas (para parse) sem estourar erro.
  & $script:Necli @NecliArgs 2>&1 | ForEach-Object { "$_" }
}

function Test-VpnConnected {
  $out = Invoke-Necli @("status")
  # "Connected" presente e sem "Disconnected/Not connected" => conectado.
  ($out -match '(?i)connected') -and -not ($out -match '(?i)disconnected|not\s+connected')
}

function Connect-Vpn {
  param([pscredential]$Cred)

  if (Test-VpnConnected) { Ok "VPN da FAI ja' conectada."; return $true }

  $plain = ConvertFrom-SecureToPlain $Cred.Password
  Info "conectando a VPN $Server (dominio $Domain, usuario $($Cred.UserName))..."

  # Sintaxe padrao do NECLI. Se a sua versao usar flags diferentes, ajuste aqui
  # (rode "NECLI help connect" para ver as opcoes da sua build).
  $out = Invoke-Necli @(
    "connect",
    "-s", $Server,
    "-d", $Domain,
    "-u", $Cred.UserName,
    "-p", $plain
  )
  $plain = $null  # nao deixa a senha viva na memoria

  # da' um tempo pro tunel subir e confere o status
  for ($i = 0; $i -lt 35; $i++) {
    if (Test-VpnConnected) { Ok "VPN conectada."; return $true }
    Start-Sleep -Seconds 1
  }

  Fail "VPN nao conectou. Saida do NECLI:"
  $out | ForEach-Object { Write-Host "    $_" }
  Write-Host ""
  Warn "Dicas: confira usuario/senha (-Reconfigure); na 1a vez talvez precise"
  Warn "abrir o NetExtender grafico uma vez para ACEITAR o certificado do servidor."
  return $false
}

function Disconnect-Vpn {
  Info "desconectando a VPN..."
  Invoke-Necli @("disconnect") | Out-Null
  Start-Sleep -Seconds 1
  if (Test-VpnConnected) { Warn "ainda aparece conectada; verifique no NetExtender." }
  else { Ok "VPN desconectada." }
}

# ===========================================================================
# 3) Wake-on-LAN (mesma logica do send-wol.ps1)
# ===========================================================================
function Send-Wol {
  param([string]$MacAddr, [string]$Target, [int]$Port, [int]$Count = 1)

  $m = $MacAddr -replace '[:\-]', ''
  if ($m -notmatch '^[0-9a-fA-F]{12}$') { throw "MAC invalido: $MacAddr" }
  $macBytes = for ($i = 0; $i -lt 12; $i += 2) { [Convert]::ToByte($m.Substring($i, 2), 16) }
  $packet = (, [byte]0xFF * 6) + ($macBytes * 16)   # 6x FF + 16x MAC = 102 bytes

  for ($n = 0; $n -lt $Count; $n++) {
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.EnableBroadcast = $true
    $udp.Connect($Target, $Port)
    [void]$udp.Send($packet, $packet.Length)
    $udp.Close()
  }
  Ok "magic packet enviado (${Count}x) -> $Target (porta $Port) para $MacAddr"
}

# ===========================================================================
# 4) Workstation up? — TCP na porta SSH com timeout curto
# ===========================================================================
function Test-Port {
  param([string]$ComputerName, [int]$Port, [int]$TimeoutMs = 2500)
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $iar = $client.BeginConnect($ComputerName, $Port, $null, $null)
    if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $client.Connected) {
      $client.EndConnect($iar); return $true
    }
    return $false
  } catch { return $false }
  finally { $client.Close() }
}

# ===========================================================================
#  FLUXO PRINCIPAL
# ===========================================================================
Write-Host ""
Write-Host "=== wake-fai (Windows) — VPN FAI -> WoL -> SSH ===" -ForegroundColor Magenta

# (0) NECLI
$script:Necli = Find-Necli -Override $NecliPath
if (-not $script:Necli) {
  Fail "NetExtender (NECLI.exe) nao encontrado nesta maquina."
  Write-Host ""
  Write-Host "  Instale o SonicWall NetExtender para Windows (o app inclui o NECLI):"
  Write-Host "    https://www.sonicwall.com/products/remote-access/vpn-clients/"
  Write-Host "  Depois rode de novo, ou aponte o caminho com:"
  Write-Host "    .\wake-fai.ps1 -NecliPath `"C:\Program Files\SonicWall\NetExtender\NECLI.exe`""
  exit 1
}
Ok "NECLI: $script:Necli"

# (1) credenciais
$cred = Get-VpnCredential -Force:$Reconfigure

# (2) VPN
$connectedNow = $false
if (Test-VpnConnected) {
  Ok "VPN da FAI ja' conectada."
} else {
  if (-not (Connect-Vpn -Cred $cred)) { exit 1 }
  $connectedNow = $true
}

# (3) workstation ligada?
if (Test-Port -ComputerName $WsIp -Port $WsPort) {
  Ok "workstation de pe' (porta $WsPort aberta)."
} else {
  Info "workstation offline; mandando Wake-on-LAN..."
  Send-Wol -MacAddr $Mac -Target $WolTarget -Port $WolPort -Count 3
  Write-Host -NoNewline "→ esperando bootar (ate ${BootWait}s): "
  $deadline = $BootWait
  $up = $false
  while ($deadline -gt 0) {
    if (Test-Port -ComputerName $WsIp -Port $WsPort -TimeoutMs 2000) { $up = $true; break }
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 3
    $deadline -= 3
  }
  Write-Host ""
  if (-not $up) {
    Fail "nao subiu em ${BootWait}s. Pode ser BIOS/WoL — repita ou verifique."
    exit 1
  }
  Ok "up!"
}

# (4) SSH
if (-not $NoSsh) {
  Info "ssh $WsUser@$WsIp"
  & ssh "$WsUser@$WsIp"
} else {
  Info "(-NoSsh) pulando a etapa de SSH."
}

# (5) ao sair, oferece desconectar (so se fomos nos que ligamos)
if (-not $KeepVpn -and $connectedNow) {
  Write-Host ""
  $ans = Read-Host "Desconectar a VPN da FAI agora? [Y/n]"
  if ($ans -match '^(n|nao|no)') { Ok "VPN mantida conectada." }
  else { Disconnect-Vpn }
} elseif ($connectedNow) {
  Ok "VPN mantida conectada (-KeepVpn)."
}
