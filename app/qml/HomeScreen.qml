import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Hub central — redesign HBO Max: barra de topo + saudação + três grandes
// cartões (TV ao Vivo / Filmes / Séries) + ações secundárias. Fundo gradiente
// vem do Main.qml.
Item {
    id: root
    anchors.fill: parent

    Connections {
        target: channels
        function onListReady(n) { Window.window.notify(n + " canais carregados") }
        function onError(m) { Window.window.notify(m) }
    }

    function go(key) {
        if (key === "home")          {}
        else if (key === "live")     app.navigate("player")
        else if (key === "movies")   app.navigate("movies")
        else if (key === "series")   app.navigate("series")
        else if (key === "profile")  app.navigate("settings")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            Layout.fillWidth: true
            active: "home"
            showSearch: false
            onTabClicked: function(key) { root.go(key) }
        }

        // Corpo
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 26

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "O que você quer assistir?"
                    color: Theme.text
                    font.pixelSize: 30; font.bold: true
                }

                // Três grandes cartões
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 22
                    BigCard {
                        icon: "tvdig/tv2.svg"; title: "TV ao Vivo"
                        onClicked: app.navigate("player")
                    }
                    BigCard {
                        icon: "tvdig/filmes.svg"; title: "Filmes"
                        onClicked: app.navigate("movies")
                    }
                    BigCard {
                        icon: "tvdig/series.svg"; title: "Séries"
                        onClicked: app.navigate("series")
                    }
                }

                // Ações secundárias
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14
                    Pill { icon: "mi/settings.svg"; label: "Configurações"
                        onClicked: app.navigate("settings") }
                    Pill { icon: "mi/refresh.svg"; label: "Recarregar"
                        onClicked: { channels.loadList(true); Window.window.notify("Recarregando lista...") } }
                    Pill { icon: "mi/logout.svg"; label: "Sair"; danger: true
                        onClicked: { auth.logout(); app.navigate("login") } }
                }
            }

            // Vencimento no rodapé
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 28
                text: auth.expiresAt ? ("Vencimento: " + auth.expiresAt) : ""
                color: Theme.subtext; font.pixelSize: 14; font.bold: true
            }
        }
    }

    // Cartão grande com ícone + título
    component BigCard: Rectangle {
        id: bc
        property string icon: ""
        property string title: ""
        signal clicked()
        implicitWidth: 250; implicitHeight: 200
        radius: 16
        color: hovered ? Theme.panel2 : Theme.panel
        border.color: hovered ? Theme.brand : Theme.border
        border.width: hovered ? 2 : 1
        property bool hovered: false
        scale: hovered ? 1.03 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "qrc:/qt/qml/SwiftIPTV/resources/icons/" + bc.icon
                sourceSize.width: 84; sourceSize.height: 84; smooth: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: bc.title; color: Theme.text
                font.pixelSize: 20; font.bold: true
            }
        }
        MouseArea {
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onEntered: bc.hovered = true
            onExited: bc.hovered = false
            onClicked: bc.clicked()
        }
    }

    // Pílula de ação (ícone + texto)
    component Pill: Rectangle {
        id: pl
        property string icon: ""
        property string label: ""
        property bool danger: false
        signal clicked()
        implicitWidth: row.implicitWidth + 36
        implicitHeight: 46
        radius: 23
        color: hovered ? Theme.panel2 : Theme.panel
        border.color: hovered ? (danger ? Theme.bad : Theme.brand) : Theme.border
        border.width: 1
        property bool hovered: false
        Behavior on color { ColorAnimation { duration: 120 } }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 10
            Image {
                source: "qrc:/qt/qml/SwiftIPTV/resources/icons/" + pl.icon
                sourceSize.width: 20; sourceSize.height: 20; smooth: true
            }
            Text { text: pl.label; color: pl.danger ? Theme.bad : Theme.text
                font.pixelSize: 15; font.bold: true }
        }
        MouseArea {
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onEntered: pl.hovered = true
            onExited: pl.hovered = false
            onClicked: pl.clicked()
        }
    }
}
