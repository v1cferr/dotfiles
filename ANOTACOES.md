# Anotações

> 1. Sempre pesquisar as boas práticas e o que a comunidade do NixOS está usando mais para cada pacote/software (para ter uma referência e sugestões)
> 2. Nas arquivos de configurações `.nix`, `.lua`, `.conf` e etc. Adicionar apenas uma linha de comentário `# exemplo` (resumo) para cada config logo acima para resumir o que exatamente aquela linha faz (para não poluir os arquivos de configurações de comentários)

- [x] Instalar o flameshot — v13 estável + enableWlrSupport (grim). O v14 só
      captura via portal (não funciona neste Hyprland); o v13 usa grim direto
      (useGrimAdapter). Multi-monitor: windowrule estica o overlay pelas 2 telas.
  - <https://wiki.nixos.org/wiki/Flameshot>
- [ ] Verificar se é possível adicionar estado declarativo criptografado
- [ ] Adicionar um software para notificações
- [x] Clipboard (Wayland) — cliphist + wl-clipboard, watcher no autostart do Hyprland
      e picker no wofi (SUPER+SHIFT+V). Pacotes no system/, config em home/hypr.nix.
      + wl-clip-persist: mantém a cópia viva após o app fechar (fix da imagem do
      Flameshot, que sumia do clipboard ao Flameshot sair — dono do clipboard no Wayland).
- [x] Dark mode no file manager (Dolphin) — Qt segue o GTK escuro (home/theme.nix)
- [ ] Depois que eu estiver no SSD, já configurar o WoW Ascension com o Bottles para jogarmos e eu ir configurando o sistema simultaneamente

## Mantenabilidade

- [ ] Verificar a arquitetura de pastas e melhores práticas para manunteção, organização e escalabilidade do meu repositório (dotfiles do Nix e NixOS)
- [ ] Remover todos os outros hosts e manter apenas o atual (atualmente estamos no SSD SanDisk)

## Temas (Tokyo Night e etc)

- [ ] Tema Windows 11 no file manager — DEPOIS no SSD (cosmético, ajuste visual
      no Kvantum Manager). Caminho: instalar kdePackages.qtstyleplugin-kvantum +
      vendorizar tema Win11 Kvantum (ex.: store.kde.org/p/1554628 "Win11OS-dark")
      em ~/.config/Kvantum + QT_STYLE_OVERRIDE=kvantum. Só estiliza o INTERIOR do
      Dolphin (a moldura é do Hyprland).

## Serviços Docker e etc

> Ambos com systemd (ou algo semelhante) e rodando em daemon (background)

- [ ] Adicionar o servidor de Midia (Jellyfin) com linguagem Nix
- [ ] Adicionar o duolingo rodando para fazer automaticamente com Nix
  - [ ] Instalar Ollama ou outro recomendando para rodar modelos de IA localmente

## Pacotes e softwares

- [x] Media player — VLC (GUI completa, toca tudo out-of-the-box). Pacote no system/.

## Games e Jogos

- [x] Bottles é declarativo? O APP sim (system/default.nix, com override removeWarningPopup).
      O que está DENTRO (bottles/prefixos, jogos, runners GE-Proton) é ESTADO em
      ~/.local/share/bottles — não declarável, vai por backup (regra: Nix = app+config; estado = restic).
- [x] Emulador — RPCS3 (PS3) no system/ p/ Uncharted 1/2/3 (trilogia é PS3). PS4/U4 só
      via shadPS4 (experimental). Firmware+jogos = estado (você provê). Controle Machenike
      G5 Pro: kernel 6.18 tem o driver xpad (nativo desde 6.10) + Bluetooth já ligado →
      só parear (runtime, bluetoothctl) e usar em modo Xbox/Xinput. Tudo declarativo possível feito.
