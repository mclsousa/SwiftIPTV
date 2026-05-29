import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SwiftIPTV

// Hub central do app TV DIG+ — exibido logo após o login.
// Layout: logo no topo, grade de cards, vencimento no rodapé.
//
//  [TV DIG+]
//
//  ┌────────────┐  ┌─────────┐ ┌─────────┐   ┌──────────────┐
//  │            │  │ FILMES  │ │ SÉRIES  │   │ CONFIGURAÇÕES │
//  │ TV AO VIVO │  └─────────┘ └─────────┘   ├──────────────┤
//  │            │  ┌─────────┐ ┌─────────┐   │ RECARREGAR   │
//  │            │  │ CONTA   │ │SERVIDOR │   ├──────────────┤
//  └────────────┘  └─────────┘ └─────────┘   │ SAIR         │
//                                            └──────────────┘
//  Vencimento: ...

Item {
    id: root
    anchors.fill: parent

    Connections {
        target: channels
        function onListReady(n) { Window.window.notify(n + " canais carregados") }
        function onError(m) { Window.window.notify(m) }
    }

    // Cor de fundo escura sobre o pattern hexagonal global
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: 0.85
    }

    // ───────── Logo TV DIG+ no topo ─────────
    Image {
        id: topLogo
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 26
        source: "qrc:/qt/qml/SwiftIPTV/resources/logos/logo-tvdig.png"
        sourceSize.width: 140
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // ───────── Grade central ─────────
    RowLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 30
        spacing: 18

        // ─── Card grande: TV ao Vivo ───
        Card {
            Layout.preferredWidth: 280
            Layout.preferredHeight: 300
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/tv.svg"
            iconSize: 110
            title: "TV ao Vivo"
            titleSize: 22
            onClicked: app.navigate("player")
        }

        // ─── Coluna: Filmes / Conta ───
        ColumnLayout {
            spacing: 18
            Card {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 140
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/movie.svg"
                iconSize: 60
                title: "Filmes"
                titleSize: 16
                onClicked: app.navigate("movies")
            }
            Card {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 140
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/account.svg"
                iconSize: 60
                title: "Conta"
                titleSize: 16
                onClicked: Window.window.notify("Conta (em construção)")
            }
        }

        // ─── Coluna: Séries / Servidores ───
        ColumnLayout {
            spacing: 18
            Card {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 140
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/series.svg"
                iconSize: 60
                title: "Séries"
                titleSize: 16
                onClicked: app.navigate("series")
            }
            Card {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 140
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/servers.svg"
                iconSize: 60
                title: "Servidores"
                titleSize: 16
                onClicked: app.navigate("dns")
            }
        }

        // ─── Coluna direita: 3 botões ───
        ColumnLayout {
            spacing: 14
            ActionButton {
                Layout.preferredWidth: 220
                Layout.preferredHeight: 64
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/settings.svg"
                label: "Configurações"
                onClicked: app.navigate("settings")
            }
            ActionButton {
                Layout.preferredWidth: 220
                Layout.preferredHeight: 64
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/refresh.svg"
                label: "Recarregar"
                onClicked: { channels.loadList(true); Window.window.notify("Recarregando lista...") }
            }
            ActionButton {
                Layout.preferredWidth: 220
                Layout.preferredHeight: 64
                iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/logout.svg"
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
    // Componentes inline reutilizáveis nesta tela
    // ─────────────────────────────────────────────

    // Card retangular grande com ícone topo + título embaixo
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
            spacing: 14
            Item { Layout.fillHeight: true; Layout.fillWidth: true
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

    // Botão "pílula" da coluna direita: ícone + texto, linha única
    component ActionButton: Rectangle {
        id: btn
        property string iconSource: ""
        property string label: ""
        property color  labelColor: Theme.text
        signal clicked()

        radius: 14
        color: hovered ? Theme.panel2 : Theme.panel
        border.color: hovered ? Theme.brand : Theme.border
        border.width: 1
        property bool hovered: false
        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 16
            Image {
                source: btn.iconSource
                sourceSize.width: 28
                sourceSize.height: 28
                smooth: true
            }
            Text {
                Layout.fillWidth: true
                text: btn.label
                color: btn.labelColor
                font.pixelSize: 16
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
