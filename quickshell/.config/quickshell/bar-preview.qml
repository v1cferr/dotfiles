// PREVIEW da barra QS em desenvolvimento — NÃO é a barra ativa.
// Rode pra ver:  qs -p ~/.config/quickshell/bar-preview.qml
// barExclusiveZone:0 = sobrepõe sem reservar espaço (não empurra suas janelas).
// Quando a barra atingir paridade, ela é ligada no shell.qml e a Waybar sai.
import Quickshell
import QtQuick

ShellRoot {
    Bar {
        barExclusiveZone: 0
    }
}
