import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SwiftIPTV

// Barra de topo do DIGTV+: abas de navegação + busca + logo.
// Reutilizável por TV ao Vivo, Filmes e Séries.
Rectangle {
    id: nav
    height: 64
    color: Theme.bg

    // Aba ativa: "home" | "live" | "movies" | "series"
    property string active: "live"
    // Texto da busca (two-way com a tela hospedeira)
    property alias searchText: searchField.text
    signal tabClicked(string key)
    // Expor o foco da busca para o botão "Procurar"
    function focusSearch() { searchField.forceActiveFocus() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 20
        spacing: 28

        Repeater {
            model: [
                { k: "home",   t: "Home" },
                { k: "live",   t: "TV ao Vivo" },
                { k: "movies", t: "Filmes" },
                { k: "series", t: "Séries" }
            ]
            delegate: Text {
                required property var modelData
                text: modelData.t
                color: nav.active === modelData.k ? Theme.brand : Theme.text
                font.pixelSize: 22
                font.bold: nav.active === modelData.k
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nav.tabClicked(modelData.k)
                }
            }
        }

        // Campo de busca
        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 420
            height: 38
            radius: 19
            color: Theme.panel
            border.color: Theme.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 8
                Text { text: "🔍"; color: Theme.subtext; font.pixelSize: 14 }
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    color: Theme.text
                    placeholderText: ""
                    background: null
                    verticalAlignment: TextInput.AlignVCenter
                }
            }
        }

        Item { Layout.fillWidth: true }

        Image {
            source: "qrc:/qt/qml/SwiftIPTV/resources/logos/logo-tvdig.png"
            sourceSize.height: 34
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // Linha inferior sutil
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
}
