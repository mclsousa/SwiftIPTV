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
            Text {
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: catRow.count
                color: Theme.subtext
                font.pixelSize: 14
            }
            MouseArea {
                id: catMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: side.categorySelected(catRow.name)
            }
        }
    }
}
