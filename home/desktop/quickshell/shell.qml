//@ pragma UseQApplication
// Raiz do shell: só COMPÕE os componentes (barra, OSD, mídia, notificações).
// Cada um mora no próprio arquivo; aqui não há lógica.
//
// REMOVIDO (30/07): este arquivo carregava um painel de controle de VPN inteiro
// (~190 linhas) que era CÓDIGO MORTO em três níveis, e nada disso aparecia:
//   1. chamava `$HOME/.local/bin/vpn`, caminho do setup ARCH — nesta máquina o
//      CLI é `vpn` no PATH (system/net/vpn.nix), então toda ação e todo status
//      falhavam em silêncio contra um binário inexistente;
//   2. era inalcançável — o único gatilho era `qs ipc call vpn toggle`, herdado
//      do módulo custom/vpn da WAYBAR, que foi removida na migração; nenhum bind
//      do keybinds.lua chama isso;
//   3. modelava o mundo antigo: "FAI via netExtender" e "perfis do
//      NetworkManager", quando hoje é nxBender (FAI) + openconnect (UFSCar), e
//      lia um campo `neservice` que o `vpn status-json` nem emite mais.
// O controle de VPN agora vive ANCORADO na barra, em bar/VpnPopover.qml.
import Quickshell
import QtQuick
import "root:/bar"
import "root:/notifications"
import "root:/osd"
import "root:/media"

ShellRoot {
    id: root

    // OSD (toast) de volume/mic, bottom-center no monitor principal. Componente em Osd.qml.
    Osd {}

    // Painel de controle de mídia (Spotify). Componente em Mpris.qml.
    Mpris {}

    // Barra principal — substitui a Waybar. Componente em Bar.qml.
    Bar {}

    // Notificações nativas do Quickshell (toasts + central). Daemon em Notifs.qml
    // (singleton) + UI em Notifications.qml. Dono do org.freedesktop.Notifications
    // (o swaync foi removido; o mako órfão morreu). O sino no Bar lê Notifs.count/dnd.
    Notifications {}
}
