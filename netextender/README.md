# NetExtender Dotfiles

Configurações e perfis da VPN SonicWall gerenciados via NetExtender.

A VPN SonicWall requer o uso do cliente nativo `netextender` disponível no AUR e gerencia os seus perfis globalmente em `/etc/SonicWall`.

## Perfis incluídos

- `FAI.UFSCAR` (`sslvpn` / `sonicwall`)
  - Servidor: `200.133.233.101:4433`
  - Domínio: `fai2008`
  - Usuário: `victor.ferreira`
  - Confiança de certificado armazenada

## Aplicar o perfil salvo

Como o NetExtender guarda suas configurações em diretórios do sistema `/etc`, nós utilizamos um comando para copiar o perfil rastreado no dotfiles direto para a pasta do daemon:

```bash
cd ~/dotfiles
sudo install -d -m 755 /etc/SonicWall/NetExtender/Config
sudo install -m 644 netextender/etc/SonicWall/NetExtender/Config/profile.json /etc/SonicWall/NetExtender/Config/profile.json
```

## Conectar

Utilize o script simplificado disponibilizado na pasta `scripts`:

```bash
~/dotfiles/scripts/fai-ufscar-vpn.sh
```

Ou manualmente via CLI:

```bash
sudo netExtender connect FAI.UFSCAR
```

## Dependências

- `netextender` (via AUR)
  - Instale com: `yay -S netextender`
- Requer o serviço `NEService.service` rodando (o script cuida de iniciar caso não esteja).
