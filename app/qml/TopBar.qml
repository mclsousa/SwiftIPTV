import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SwiftIPTV

// Barra de topo do redesign HBO: logo + abas + busca + perfil/conta.
// Reutilizável por TV ao Vivo / Filmes / Séries.
Rectangle {
    id: nav
    height: 66
    color: Qt.rgba(0.043, 0.035, 0.063, 0.96)   // bg quase opaco

    // Aba ativa: "home" | "live" | "movies" | "series"
    property string active: "live"
    property alias searchText: searchField.text
    property bool showSearch: true
    signal tabClicked(string key)
    function focusSearch() { searchField.forceActiveFocus() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 20
        spacing: 26

        // Logo
        Logo { markSize: 30; fontSize: 19 }

        // Abas
        Repeater {
            model: [
                { k: "home",   t: "Início" },
                { k: "live",   t: "TV ao Vivo" },
                { k: "movies", t: "Filmes" },
                { k: "series", t: "Séries" }
            ]
            delegate: Item {
                required property var modelData
                Layout.preferredWidth: tabText.implicitWidth
                Layout.fillHeight: true
                Text {
                    id: tabText
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.t
                    color: nav.active === modelData.k ? Theme.text
                           : (tabMouse.containsMouse ? Theme.text : Theme.subtext)
                    font.pixelSize: 16
                    font.bold: nav.active === modelData.k
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                // Indicador roxo da aba ativa (cresce do centro com animação)
                Rectangle {
                    anchors.top: tabText.bottom; anchors.topMargin: 6
                    anchors.horizontalCenter: tabText.horizontalCenter
                    width: nav.active === modelData.k ? tabText.implicitWidth : 0
                    height: 3; radius: 2
                    color: Theme.brand
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nav.tabClicked(modelData.k)
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Busca
        Rectangle {
            visible: nav.showSearch
            Layout.preferredWidth: 320
            height: 42
            radius: 21
            color: Qt.rgba(1, 1, 1, searchField.activeFocus ? 0.16 : 0.09)
            border.color: searchField.activeFocus ? Qt.rgba(1, 1, 1, 0.35) : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 130 } }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 12
                spacing: 8
                Image {
                    source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/search.svg"
                    sourceSize.width: 16; sourceSize.height: 16; smooth: true
                }
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    color: Theme.text
                    placeholderText: "Buscar..."
                    placeholderTextColor: Theme.subtext
                    background: null
                    verticalAlignment: TextInput.AlignVCenter
                }
            }
        }

        // Perfil / Conta -> Configurações
        Rectangle {
            width: 40; height: 40; radius: 20
            color: profMouse.containsMouse ? Theme.panel2 : Theme.panel
            border.color: Theme.border
            Image {
                anchors.centerIn: parent
                source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/account.svg"
                sourceSize.width: 22; sourceSize.height: 22; smooth: true
            }
            MouseArea {
                id: profMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: nav.tabClicked("profile")
            }
        }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
}
