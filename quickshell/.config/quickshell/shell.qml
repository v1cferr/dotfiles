// Shell principal do quickshell (usuário). Cada widget é um componente próprio:
// - Vpn.qml   : pílula de VPN (direita) + painel no hover
// - Mpris.qml : pílula de Spotify (esquerda) + painel no hover
// - Osd.qml   : OSD de volume/mic/brilho
import Quickshell
import QtQuick

ShellRoot {
    Vpn {}
    Mpris {}
    Osd {}
}
