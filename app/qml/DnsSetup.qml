import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

Item {
    anchors.fill: parent
    property string chosen: "cloudflare"

    Connections {
        target: dnsSetup
        function onApplied(ok, message) { Window.window.notify(message) }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 460
        spacing: 14

        Text { text: "Otimizar sua conexão"; color: Theme.text; font.pixelSize: 24; font.bold: true; Layout.alignment: Qt.AlignHCenter }
        Text {
            text: "Recomendamos usar um DNS rápido para melhor qualidade no IPTV"
            color: Theme.subtext; font.pixelSize: 14; Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; wrapMode: Text.WordWrap
        }

        ColumnLayout {
            Layout.fillWidth: true; spacing: 8; Layout.topMargin: 8
            Repeater {
                model: dnsSetup.providers
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    radius: 12; height: 60
                    color: chosen === modelData.key ? "#1c2540" : Theme.panel
                    border.color: chosen === modelData.key ? Theme.brand : Theme.border
                    border.width: chosen === modelData.key ? 2 : 1
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 12
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: "transparent"; border.color: chosen === modelData.key ? Theme.brand : Theme.subtext; border.width: 2
                            Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: Theme.brand; visible: chosen === modelData.key }
                        }
                        ColumnLayout {
                            spacing: 2
                            RowLayout {
                                spacing: 6
                                Text { text: modelData.name; color: Theme.text; font.pixelSize: 15; font.bold: true }
                                Text { visible: modelData.recommended; text: "⭐ Recomendado"; color: Theme.warn; font.pixelSize: 12 }
                            }
                            Text {
                                visible: modelData.primary !== ""
                                text: modelData.primary + (modelData.secondary !== "" ? "  /  " + modelData.secondary : "")
                                color: Theme.subtext; font.pixelSize: 12
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: chosen = modelData.key }
                }
            }
        }

        CheckBox {
            id: dontShow
            text: "Não mostrar novamente"
            contentItem: Text { text: dontShow.text; color: Theme.subtext; font.pixelSize: 13
                leftPadding: dontShow.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
            indicator: Rectangle {
                width: 18; height: 18; radius: 4; y: parent.height/2 - 9
                color: dontShow.checked ? Theme.brand : Theme.panel2; border.color: Theme.border
                Text { anchors.centerIn: parent; text: "✓"; color: "white"; visible: dontShow.checked; font.pixelSize: 12 }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 10; Layout.topMargin: 6
            Button {
                text: "Pular"
                onClicked: dnsSetup.skip(dontShow.checked)
                contentItem: Text { text: parent.text; color: Theme.subtext; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter }
                background: Rectangle { radius: 10; color: Theme.panel2; border.color: Theme.border }
                Layout.preferredWidth: 120; topPadding: 12; bottomPadding: 12
            }
            Button {
                text: "Aplicar e Assistir"
                onClicked: dnsSetup.applyAndWatch(chosen, dontShow.checked)
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                background: Rectangle { radius: 10; color: parent.down ? Theme.brand2 : Theme.brand }
                Layout.fillWidth: true; topPadding: 12; bottomPadding: 12
            }
        }
        Text {
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            text: "Será solicitada permissão de administrador (UAC) para alterar o DNS."
            color: Theme.subtext; font.pixelSize: 11; wrapMode: Text.WordWrap
        }
    }
}
