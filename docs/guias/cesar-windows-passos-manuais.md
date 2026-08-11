# CESAR (Windows do irmão) — os passos que o Nix não alcança

O host `cesar` é declarado em [`home/shell/ssh.nix`](../../home/shell/ssh.nix), mas
aquilo é **só o lado cliente**. Tudo o que precisa existir *dentro* do Windows —
chave autorizada, PATH, pacotes — vive fora do alcance do Nix, porque a máquina não
é NixOS e não é nossa. Este guia existe pra que isso seja **refeito em minutos** se
o Windows for reinstalado ou a conta recriada, em vez de redescoberto do zero.

Mesma natureza do `authorized_keys` do roteador (OpenWrt), pelo mesmo motivo: o repo
declara o cliente, o servidor é território de outro sistema.

## Contexto fixo

| o quê | valor |
| --- | --- |
| Host / IP | `CESAR` / `192.168.1.40` (DHCP — ver armadilha no fim) |
| Minha conta lá | `v1cferr`, **membro de Administrators** |
| Conta do dono | `drakk` — [nunca operar como ele](../../home/shell/ssh.nix) |
| sshd | `OpenSSH_for_Windows_9.5` |

⚠️ **A sessão SSH de um admin no Windows já vem com token ELEVADO.** Isso é por que
os comandos abaixo escrevem em `C:\ProgramData` e no PATH de máquina sem UAC — e
também por que o instalador do Scoop recusa a instalação sem `-RunAsAdmin`.

## 1. Login por chave

`ssh-copy-id` **não serve**: ele assume shell POSIX, e o shell padrão do sshd do
Windows é o `cmd.exe`. E como a conta é administradora, o sshd **ignora** o
`~/.ssh/authorized_keys` dela — vale só o arquivo de máquina:

```powershell
Add-Content -Encoding ascii C:\ProgramData\ssh\administrators_authorized_keys '<id_ed25519.pub>'
icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r `
  /grant Administrators:F /grant SYSTEM:F
```

⚠️ **Duas formas de errar aqui, e as duas são MUDAS** — falham voltando pra senha,
sem dizer nada ao cliente:

- `Add-Content` sem `-Encoding ascii` grava UTF-16, que o sshd não lê;
- sem o `icacls`, o arquivo fica gravável por mais gente e o sshd o **recusa**.

Validar de forma inequívoca (o `BatchMode` proíbe o prompt de senha, então só passa
se foi a chave):

```bash
ssh -o BatchMode=yes v1cferr@192.168.1.40 "echo OK"
```

## 2. Coreutils GNU na máquina inteira

O Git for Windows já embarca o userland GNU (coreutils 8.32, grep, sed, awk, less,
vim) em `C:\Program Files\Git\usr\bin` — **não é preciso instalar nada**, só expor.

```powershell
$d = "C:\Program Files\Git\usr\bin"
$p = [Environment]::GetEnvironmentVariable("PATH","Machine")
if ($p -split ";" -notcontains $d) {
  [Environment]::SetEnvironmentVariable("PATH", $p.TrimEnd(";") + ";" + $d, "Machine")
}
```

⚠️ **APÊNDICE NO FIM, nunca no início** — e essa ordem é a decisão inteira. Esse
diretório traz `find.exe`, `sort.exe`, `tar.exe`, `link.exe` e `echo.exe`, que têm
homônimos do Windows com semântica **completamente diferente**. Prependar quebra
script `.bat` e build MSVC (o `link.exe` do MSYS não é o linker da Microsoft). No
fim, ganha-se tudo que não conflita e não se perde nada. Conferir com `where`:

```text
where find  → C:\Windows\System32\find.exe          (Windows ganha, correto)
              C:\Program Files\Git\usr\bin\find.exe
where ls    → C:\Program Files\Git\usr\bin\ls.exe   (só existe GNU)
```

⚠️ **No PowerShell isso rende menos do que parece**: `ls`, `cat`, `cp`, `rm`, `sort`,
`curl`, `echo` são ALIASES nativos, e alias vence PATH sempre. Lá é preciso digitar
`ls.exe`. No `cmd` não há aliases, então funciona direto — e dentro do bash a questão
nem existe.

Desfazer = remover essa entrada do PATH de máquina. Nada mais é tocado.

## 3. Scoop (por usuário) e ferramenta moderna

```cmd
cd /d %USERPROFILE%
powershell -ExecutionPolicy Bypass -Command "irm get.scoop.sh -outfile scoop-install.ps1; .\scoop-install.ps1 -RunAsAdmin; del scoop-install.ps1"
scoop install ripgrep fd jq
```

O `-ExecutionPolicy Bypass` vale só pro processo — não altera a política da máquina.
O `-RunAsAdmin` é obrigatório pelo token elevado da sessão SSH (ver contexto acima).
Instala em `%USERPROFILE%\scoop`, ou seja, **sai junto com o perfil**.

## 4. Claude Code (perfil próprio)

```cmd
cd /d %USERPROFILE%
curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
```

Sem Node, sem admin, instala em `%USERPROFILE%\.local\bin\claude.exe`. O instalador
**não** põe isso no PATH; fazer à mão, no ramo `User`:

```powershell
[Environment]::SetEnvironmentVariable('PATH',
  [Environment]::GetEnvironmentVariable('PATH','User') + ';C:\Users\v1cferr\.local\bin', 'User')
```

⚠️ **NÃO usar `setx PATH "%PATH%;..."`**, que é o conselho que aparece em todo lugar:
`%PATH%` expande pro PATH **combinado** (máquina + usuário) e o `setx` grava tudo no
ramo do usuário — duplicando o PATH da máquina dentro do seu — além de **truncar em
1024 caracteres**, comendo o resto sem avisar.

⚠️ Rodar os dois blocos **fora** de `C:\Users\drakk\dev\...`: eles escrevem arquivo
temporário no diretório atual, e sujar o `git status` do repo do dono é rastro que
não deveria existir.

## Armadilhas que sobrevivem a este guia

- **O IP é DHCP.** Mudou o endereço, o alias quebra. O conserto é reserva de DHCP no
  OpenWrt — não mais uma opção `my.*` no repo.
- **O aviso de post-quantum a cada conexão não é config nossa**: o servidor é OpenSSH
  9.5 e o `mlkem768x25519` só existe do 9.9 em diante. Some quando a Microsoft
  atualizar o Win32-OpenSSH. Deliberadamente **não** silenciado com `WarnWeakCrypto`.
- **`where bash` mente lá.** O único `bash` no PATH é `C:\Windows\System32\bash.exe`,
  que é o stub legado do WSL (sem distro instalada). O bash real é
  `C:\Program Files\Git\bin\bash.exe`, e não aparece porque só o `Git\cmd` está no
  PATH.
