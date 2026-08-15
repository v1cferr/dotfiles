// Popover de ESTATÍSTICAS da VPN, aberto pelo HOVER no pill 󰦝 da barra. Uma
// coluna por VPN CONECTADA: veredito de qualidade, gráfico do último minuto,
// latência, jitter, perda, tráfego e tempo no ar. Estado e cálculo ficam no Bar e
// chegam por referência via `bar` (mesmo contrato dos outros popovers da pasta).
//
// DIVISÃO com o VpnPopover (que é o do CLIQUE): aqui é INFORMAÇÃO, lá é AÇÃO.
// Por isso este abre no hover e aquele não — painel com botão que aparece sozinho
// some na primeira distração, e este não tem nada pra clicar (mesmo critério do
// calendário e do popover de métricas). Os dois ancoram no MESMO ponto da barra,
// então o Bar esconde este enquanto o menu de ações está aberto.
//
// LARGURA 360 e não 300: na 1ª versão o rodapé cortava o IP da sonda
// ("200.136.209…") e as linhas ficavam espremidas. Painel de diagnóstico com dado
// elidido é contraditório — quem abre está justamente atrás do detalhe.
//
// O GRÁFICO é o motivo de o painel existir. "A VPN está estável?" é pergunta
// sobre o TEMPO: um "34 ms" sozinho não distingue túnel liso de túnel que oscilou
// de 30 a 900ms no último minuto. Uma barra por segundo (60 = a janela inteira da
// sonda), a mais recente à direita, e a escala começa em ZERO — auto-escalar pelo
// mínimo faria 0,5ms de variação virar um serrote dramático, o oposto da leitura
// honesta.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"

PanelWindow {
    id: statsPop
    required property var bar

    visible: bar.vpnStatsPopVisible
    screen: bar.popScreen || bar.screenPrimary
    anchors {
        top: true
        left: true
    }
    margins {
        top: 4 // = gaps_out do Hyprland (o barExclusiveZone 30 já está descontado)
        left: bar.popLeft(statsPop.implicitWidth)
    }
    exclusiveZone: 0
    implicitWidth: 360
    implicitHeight: card.implicitHeight
    color: "transparent"

    // ms com vírgula (pt-BR) e casas só quando importam: "34 ms" lê melhor que
    // "34,00 ms", e 0,8 ms de jitter viraria "1 ms" arredondado.
    function fmtMs(v, digits) {
        return v.toFixed(digits).replace(".", ",") + " ms";
    }

    component StatRow: RowLayout {
        id: sr
        property string label: ""
        property string value: ""
        property string hint: ""
        property color valueColor: Theme.colText

        Layout.fillWidth: true
        spacing: 10

        Text {
            Layout.minimumWidth: 62 // rótulos alinhados: a coluna de valores não dança
            text: sr.label
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 11
        }
        Text {
            Layout.fillWidth: true
            text: sr.hint
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 10
            horizontalAlignment: Text.AlignRight
        }
        Text {
            text: sr.value
            color: sr.valueColor
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.bold: true
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 28
        radius: 12
        color: Theme.colBg
        border.color: Theme.colBorder
        border.width: 1

        HoverHandler {
            onHoveredChanged: statsPop.bar.vpnStatsPopHovered = hovered
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Repeater {
                model: statsPop.bar.vpnStatsList

                delegate: ColumnLayout {
                    id: blk
                    required property var modelData
                    required property int index
                    readonly property var s: blk.modelData
                    readonly property var pr: statsPop.bar.vpnProbeStat[blk.s.id] || null
                    readonly property var q: statsPop.bar.vpnQuality(blk.s, blk.pr)
                    readonly property var series: statsPop.bar.vpnProbeSeries[blk.s.id] || []
                    readonly property var rate: statsPop.bar.vpnRate(blk.s.iface || "")
                    // Teto do gráfico: 60ms de piso p/ o caso normal não virar serrote,
                    // e 15% acima do pico quando ele passa disso (aí a escala é o pico).
                    readonly property real scaleTop: Math.max(60, (blk.pr ? blk.pr.max : 0) * 1.15)

                    Layout.fillWidth: true
                    spacing: 7

                    // separador entre VPNs (só quando as duas estão de pé)
                    Rectangle {
                        visible: blk.index > 0
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                        implicitHeight: 1
                        color: Theme.colBorder
                        opacity: 0.5
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "󰦝  " + blk.s.name
                            color: Theme.colAccent
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        // Veredito — a linha que responde "está boa?" sem ler o resto.
                        Rectangle {
                            implicitWidth: verdict.implicitWidth + 18
                            implicitHeight: 20
                            radius: 6
                            color: "transparent"
                            border.color: blk.q.color
                            border.width: 1
                            Text {
                                id: verdict
                                anchors.centerIn: parent
                                text: blk.q.label
                                color: blk.q.color
                                font.family: Theme.uiFont
                                font.pixelSize: 10
                            }
                        }
                    }

                    // Gráfico: uma barra por segundo, a mais recente à direita.
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: 3
                        implicitHeight: 40

                        Text {
                            anchors.centerIn: parent
                            visible: blk.series.length < 2
                            text: blk.s.probe ? "medindo…" : "sem alvo de sonda dentro do túnel"
                            color: Theme.colDim
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            font.italic: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            visible: blk.series.length >= 2
                            spacing: 1

                            Repeater {
                                model: blk.series
                                delegate: Item {
                                    id: sample
                                    required property var modelData
                                    // pacote sem resposta = barra cheia em vermelho
                                    // apagado: o buraco tem de SALTAR, não sumir. O teste
                                    // é largo porque o null da série pode chegar aqui como
                                    // undefined, dependendo de como o modelo é convertido.
                                    readonly property bool dead: sample.modelData === null || sample.modelData === undefined || isNaN(sample.modelData)

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: sample.dead ? parent.height : Math.max(2, parent.height * Math.min(1, sample.modelData / blk.scaleTop))
                                        radius: 1
                                        opacity: sample.dead ? 0.45 : 1
                                        color: sample.dead ? Theme.colRed : Theme.colTeal
                                    }
                                }
                            }
                        }
                    }

                    // Legenda do gráfico: sem ela o desenho não diz o que cobre — e
                    // "1 pacote/s" é a informação que separa este painel de um chute.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 3
                        spacing: 10
                        Text {
                            Layout.fillWidth: true
                            text: blk.pr && blk.pr.n > 0 ? "últimos " + blk.pr.n + "s · 1 pacote/s" : "sonda contínua · 1 pacote/s"
                            color: Theme.colDim
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                        }
                        Text {
                            visible: blk.pr !== null && blk.pr.answered > 0
                            text: blk.pr ? "mín " + Math.round(blk.pr.min) + " · máx " + Math.round(blk.pr.max) + " ms" : ""
                            color: Theme.colDim
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                        }
                    }

                    StatRow {
                        label: "Latência"
                        value: blk.pr && blk.pr.answered > 0 ? statsPop.fmtMs(blk.pr.avg, 0) : "sem resposta"
                        valueColor: blk.pr && blk.pr.answered > 0 ? Theme.colText : Theme.colRed
                    }
                    StatRow {
                        // Desvio padrão da janela — o que trava SSH e chamada não é a
                        // média alta, é a variação.
                        label: "Jitter"
                        value: blk.pr && blk.pr.answered > 0 ? statsPop.fmtMs(blk.pr.mdev, 1) : "—"
                        valueColor: blk.pr && blk.pr.mdev > 10 ? Theme.colPeach : Theme.colText
                    }
                    StatRow {
                        label: "Perda"
                        hint: blk.pr && blk.pr.n > 0 ? blk.pr.lost + " de " + blk.pr.n + " pacotes" : ""
                        value: blk.pr && blk.pr.n > 0 ? blk.pr.loss.toFixed(blk.pr.loss > 0 && blk.pr.loss < 10 ? 1 : 0).replace(".", ",") + "%" : "—"
                        valueColor: blk.pr && blk.pr.loss > 0 ? (blk.pr.loss >= 20 ? Theme.colRed : Theme.colPeach) : Theme.colText
                    }
                    StatRow {
                        label: "No ar"
                        value: statsPop.bar.fmtDur(blk.s.uptime || 0)
                    }
                    StatRow {
                        label: "Tráfego"
                        value: "↓" + statsPop.bar.fmtBytes(blk.s.rx || 0) + "   ↑" + statsPop.bar.fmtBytes(blk.s.tx || 0)
                    }
                    StatRow {
                        label: "Taxa"
                        value: "↓" + statsPop.bar.fmtRate(blk.rate.rx) + "/s   ↑" + statsPop.bar.fmtRate(blk.rate.tx) + "/s"
                    }
                    // Erros/descartes só aparecem quando existem: linha zerada todo dia
                    // é ruído que treina o olho a ignorar justamente o dia em que sobe.
                    StatRow {
                        visible: (blk.s.errors || 0) + (blk.s.drops || 0) > 0
                        label: "Erros"
                        value: (blk.s.errors || 0) + " · " + (blk.s.drops || 0) + " descartes"
                        valueColor: Theme.colPeach
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 5
                        implicitHeight: 1
                        color: Theme.colBorder
                        opacity: 0.5
                    }

                    // Rodapé em DUAS linhas, sem elide: é onde mora o "de onde saiu
                    // esse número", e cortar o IP da sonda anula o propósito.
                    Text {
                        Layout.fillWidth: true
                        text: (blk.s.iface || "?") + " · " + (blk.s.ip || "?") + " · MTU " + (blk.s.mtu || 0)
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: 10
                    }
                    Text {
                        Layout.fillWidth: true
                        text: blk.s.probe ? "sonda " + blk.s.probe : "sem alvo de sonda"
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
