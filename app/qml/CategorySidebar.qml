import QtQuick
import QtQuick.Controls.Basic
import SwiftIPTV

// Coluna de categorias: nome + contagem, item selecionado em amarelo.
// Reutilizável por TV ao Vivo / Filmes / Séries.
Rectangle {
    id: side
    color: Theme.bg

    property var categoryModel: null        // CategoryListModel
    property string current: ""             // categoria selecionada (name)
    signal categorySelected(string name)
    signal lockedCategoryClicked(string name)   // categoria bloqueada -> host pede PIN

    // Reavalia o estado de cadeado quando o controle parental muda.
    property int lockTick: 0
    Connections { target: channels; function onParentalChanged() { side.lockTick++ } }

    ListView {
        id: lv
        anchors.fill: parent
        clip: true
        model: side.categoryModel
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { }

        delegate: Rectangle {
            id: catRow
            required property string name
            required property int count
            property bool locked: (side.lockTick, channels.isCategoryLocked(name))
            width: ListView.view.width
            height: 56
            color: side.current === name ? Theme.panel2
                   : (catMouse.containsMouse ? Theme.panel : "transparent")

            Rectangle {
                width: 4; height: parent.height
                color: Theme.brand
                visible: side.current === catRow.name
            }
            Text {
                anchors.left: parent.left; anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 70
                text: catRow.name
                color: side.current === catRow.name ? Theme.brand : Theme.text
                font.pixelSize: 15
                font.bold: side.current === catRow.name
                elide: Text.ElideRight
            }
            // Cadeado (categoria bloqueada) OU contagem
            Image {
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: catRow.locked
                source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/lock.svg"
                sourceSize.width: 18; sourceSize.height: 18; opacity: 0.85
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: !catRow.locked
                text: catRow.count
                color: Theme.subtext
                font.pixelSize: 14
            }
            MouseArea {
                id: catMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: catRow.locked ? side.lockedCategoryClicked(catRow.name)
                                         : side.categorySelected(catRow.name)
            }
        }
    }
}
