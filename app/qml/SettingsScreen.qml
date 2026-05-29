import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Tela de Configurações do TV DIG+ (Fase 4 do redesign).
// Layout do modelo: título centralizado + voltar, grade de "pílulas"
// (ícone + texto), e Endereço MAC / conta no rodapé.
Item {
    id: root
    anchors.fill: parent

    // MAC do dispositivo (calculado uma vez ao abrir a tela).
    readonly property string mac: app.macAddress()

    // Fundo escuro sobre o pattern hexagonal global
    Rectangle { anchors.fill: parent; color: Theme.bg; opacity: 0.85 }

    // ───────── Cabeçalho: voltar + título ─────────
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 22
        height: 48

        // Botão voltar (para a Home)
        Rectangle {
            id: backBtn
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 44; radius: 22
            color: backMouse.containsMouse ? Theme.panel2 : "transparent"
            Image {
                anchors.centerIn: parent
                source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/back.svg"
                sourceSize.width: 26; sourceSize.height: 26; smooth: true
            }
            MouseArea {
                id: backMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: app.navigate("home")
            }
        }

        Text {
            anchors.centerIn: parent
            text: "Configurações"
            color: Theme.text
            font.pixelSize: 26; font.bold: true
        }
    }

    // ───────── Grade de opções ─────────
    GridLayout {
        anchors.centerIn: parent
        columns: 3
        rowSpacing: 18
        columnSpacing: 18

        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/dns.svg"
            label: "Otimizar Conexão"
            sub: "Trocar o DNS do PC"
            onClicked: app.navigate("dns")
        }
        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/pulse.svg"
            label: "Diagnóstico de Rede"
            sub: "Latência, velocidade, servidores"
            onClicked: app.navigate("diagnostic")
        }
        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/refresh.svg"
            label: "Recarregar Lista"
            sub: "Buscar canais atualizados"
            onClicked: { channels.loadList(true); Window.window.notify("Recarregando lista...") }
        }
        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/trash.svg"
            label: "Limpar Cache"
            sub: "Apagar a lista salva em disco"
            onClicked: {
                var n = channels.clearCache()
                Window.window.notify(n + " arquivo(s) de cache removido(s)")
            }
        }
        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/info.svg"
            label: "Sobre o App"
            sub: "DIGTV+ v" + app.appVersion
            onClicked: Window.window.notify("DIGTV+ v" + app.appVersion)
        }
        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/logout.svg"
            label: "Sair da Conta"
            sub: "Encerrar a sessão"
            labelColor: Theme.bad
            onClicked: { auth.logout(); app.navigate("login") }
        }
    }

    // ───────── Rodapé: conta + MAC + versão ─────────
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        spacing: 4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
                var u = auth.usernameIptv ? auth.usernameIptv : auth.username
                var parts = []
                if (u) parts.push("Usuário: " + u)
                if (auth.expiresAt) parts.push("Vence: " + auth.expiresAt)
                return parts.join("    •    ")
            }
            color: Theme.subtext; font.pixelSize: 13; font.bold: true
            visible: text !== ""
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Endereço MAC: " + (root.mac ? root.mac : "—") + "    •    DIGTV+ v" + app.appVersion
            color: Theme.subtext; font.pixelSize: 12
        }
    }

    // ─────────────────────────────────────────────
    // Pílula de opção: ícone + título + subtítulo
    // ─────────────────────────────────────────────
    component OptionButton: Rectangle {
        id: opt
        property string iconSource: ""
        property string label: ""
        property string sub: ""
        property color  labelColor: Theme.text
        signal clicked()

        Layout.preferredWidth: 300
        Layout.preferredHeight: 76
        radius: 14
        color: hovered ? Theme.panel2 : Theme.panel
        border.color: hovered ? Theme.brand : Theme.border
        border.width: 1
        property bool hovered: false
        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18; anchors.rightMargin: 16
            spacing: 16
            Image {
                source: opt.iconSource
                sourceSize.width: 30; sourceSize.height: 30; smooth: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: opt.label
                    color: opt.labelColor
                    font.pixelSize: 16; font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: opt.sub !== ""
                    text: opt.sub
                    color: Theme.subtext
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onEntered: opt.hovered = true
            onExited:  opt.hovered = false
            onClicked: opt.clicked()
        }
    }
}
