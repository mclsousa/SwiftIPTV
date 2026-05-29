import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Hub central do app TV DIG+ — exibido logo após o login.
// Layout (alinhado ao modelo TV DIG+): logo no topo, três blocos centrais de
// MESMA ALTURA (card grande "TV ao Vivo" | grade 2x2 | coluna de 3 pílulas),
// vencimento no rodapé.
Item {
    id: root
    anchors.fill: parent

    // Altura comum dos três blocos centrais — garante alinhamento perfeito.
    readonly property int blockH: 320
    readonly property int gap: 16

    Connections {
        target: channels
        function onListReady(n) { Window.window.notify(n + " canais carregados") }
        function onError(m) { Window.window.notify(m) }
    }

    Rectangle { anchors.fill: parent; color: Theme.bg; opacity: 0.85 }

    // ───────── Logo TV DIG+ no topo ─────────
    Image {
        id: topLogo
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 26
        source: "qrc:/qt/qml/SwiftIPTV/resources/logos/logo-tvdig.png"
        sourceSize.width: 130
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // ───────── Blocos centrais ─────────
    RowLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 24
        spacing: 18

        // ─── Card grande: TV ao Vivo ───
        Card {
            Layout.preferredWidth: 300
            Layout.preferredHeight: root.blockH
            Layout.alignment: Qt.AlignTop
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/tvdig/tv2.svg"
            iconSize: 120
            title: "TV ao Vivo"
            titleSize: 22
            onClicked: app.navigate("player")
        }

        // ─── Grade 2x2: Filmes / Séries / Conta / Servidores ───
        GridLayout {
            Layout.alignment: Qt.AlignTop
            columns: 2
            rowSpacing: root.gap
            columnSpacing: root.gap
            property int cardW: 158
            property int cardH: (root.blockH - root.gap) / 2

            Card {
                Layout.preferredWidth: parent.cardW; Layout.preferredHeight: parent.cardH
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/tvdig/filmes.svg"
                iconSize: 56; title: "Filmes"; titleSize: 16
                onClicked: app.navigate("movies")
            }
            Card {
                Layout.preferredWidth: parent.cardW; Layout.preferredHeight: parent.cardH
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/tvdig/series.svg"
                iconSize: 56; title: "Séries"; titleSize: 16
                onClicked: app.navigate("series")
            }
            Card {
                Layout.preferredWidth: parent.cardW; Layout.preferredHeight: parent.cardH
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/tvdig/conta.svg"
                iconSize: 56; title: "Conta"; titleSize: 16
                onClicked: Window.window.notify("Conta: " + (auth.usernameIptv ? auth.usernameIptv : auth.username)
                                                 + (auth.expiresAt ? "  —  vence " + auth.expiresAt : ""))
            }
            Card {
                Layout.preferredWidth: parent.cardW; Layout.preferredHeight: parent.cardH
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/tvdig/servidores.svg"
                iconSize: 56; title: "Servidores"; titleSize: 16
                onClicked: app.navigate("dns")
            }
        }

        // ─── Coluna direita: 3 pílulas ───
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: root.gap
            property int pillW: 230
            property int pillH: (root.blockH - 2 * root.gap) / 3

            ActionButton {
                Layout.preferredWidth: parent.pillW; Layout.preferredHeight: parent.pillH
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/tvdig/settingsv2.svg"
                label: "Configurações"
                onClicked: app.navigate("settings")
            }
            ActionButton {
                Layout.preferredWidth: parent.pillW; Layout.preferredHeight: parent.pillH
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/tvdig/recarregar.svg"
                label: "Recarregar"
                onClicked: { channels.loadList(true); Window.window.notify("Recarregando lista...") }
            }
            ActionButton {
                Layout.preferredWidth: parent.pillW; Layout.preferredHeight: parent.pillH
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/tvdig/sair.svg"
                label: "Sair"
                labelColor: Theme.bad
                onClicked: { auth.logout(); app.navigate("login") }
            }
        }
    }

    // ───────── Vencimento no rodapé ─────────
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        text: auth.expiresAt ? ("Vencimento: " + auth.expiresAt) : ""
        color: Theme.subtext
        font.pixelSize: 14
        font.bold: true
    }

    // ─────────────────────────────────────────────
    // Componentes inline
    // ─────────────────────────────────────────────

    // Card com ícone centralizado + título embaixo
    component Card: Rectangle {
        id: card
        property string iconSource: ""
        property int    iconSize: 64
        property string title: ""
        property int    titleSize: 16
        signal clicked()

        radius: 18
        color: hovered ? Theme.panel2 : Theme.panel
        border.color: hovered ? Theme.brand : Theme.border
        border.width: 1
        property bool hovered: false
        Behavior on color { ColorAnimation { duration: 120 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            Item {
                Layout.fillHeight: true; Layout.fillWidth: true
                Image {
                    anchors.centerIn: parent
                    source: card.iconSource
                    sourceSize.width: card.iconSize
                    sourceSize.height: card.iconSize
                    smooth: true
                }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: card.title
                color: Theme.text
                font.pixelSize: card.titleSize
                font.bold: true
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: card.hovered = true
            onExited:  card.hovered = false
            onClicked: card.clicked()
        }
    }

    // Pílula: ícone + texto numa linha
    component ActionButton: Rectangle {
        id: btn
        property string iconSource: ""
        property string label: ""
        property color  labelColor: Theme.text
        signal clicked()

        radius: 16
        color: hovered ? Theme.panel2 : Theme.panel
        border.color: hovered ? Theme.brand : Theme.border
        border.width: 1
        property bool hovered: false
        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 18
            spacing: 16
            Image {
                source: btn.iconSource
                sourceSize.width: 30
                sourceSize.height: 30
                smooth: true
            }
            Text {
                Layout.fillWidth: true
                text: btn.label
                color: btn.labelColor
                font.pixelSize: 17
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: btn.hovered = true
            onExited:  btn.hovered = false
            onClicked: btn.clicked()
        }
    }
}
