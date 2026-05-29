import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Tela de Filmes (VOD) em 3 colunas (mesmo padrão da TV ao Vivo):
//   categorias (+ "Tudo")  |  lista de filmes  |  player + controles
// Dá pra navegar/escolher outro filme enquanto um toca.
Item {
    id: root
    anchors.fill: parent
    focus: true

    property string currentCategory: ""     // "" = Tudo
    property int    currentRow: -1

    readonly property bool isFullscreen: Window.window && Window.window.visibility === Window.FullScreen
    function toggleFullscreen() {
        var w = Window.window
        w.visibility = (w.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
    }

    function setCategory(name) {
        root.currentCategory = name
        channels.moviesModel.categoryFilter = name
        root.currentRow = -1
    }
    function playRow(row) {
        if (row < 0 || row >= channels.moviesModel.count) return
        root.currentRow = row
        var it = channels.moviesModel.get(row)
        if (it && it.channelId) player.playById(it.channelId)
    }

    Component.onCompleted: { forceActiveFocus(); channels.moviesModel.filter = "" }
    Connections {
        target: channels
        function onError(m) { Window.window.notify(m) }
    }
    Keys.onPressed: function(e) {
        if (e.key === Qt.Key_F11) { toggleFullscreen(); e.accepted = true }
        else if (e.key === Qt.Key_Escape && root.isFullscreen) { toggleFullscreen(); e.accepted = true }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopNav {
            id: topNav
            Layout.fillWidth: true
            visible: !root.isFullscreen
            active: "movies"
            onTabClicked: function(key) {
                vodPlayer.stop()
                if (key === "home")        app.navigate("home")
                else if (key === "live")   app.navigate("player")
                else if (key === "series") app.navigate("series")
            }
            onSearchTextChanged: channels.moviesModel.filter = topNav.searchText
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Col 1: categorias (+ Tudo)
            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                visible: !root.isFullscreen
                color: Theme.bg

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Botão "Tudo"
                    Rectangle {
                        Layout.fillWidth: true
                        height: 46
                        color: root.currentCategory === "" ? Theme.panel2 : (tudoMouse.containsMouse ? Theme.panel : "transparent")
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 14
                            Text { text: "Tudo"; color: root.currentCategory === "" ? Theme.brand : Theme.text
                                font.pixelSize: 15; font.bold: root.currentCategory === ""; Layout.fillWidth: true }
                        }
                        MouseArea { id: tudoMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.setCategory("") }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                    CategorySidebar {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        categoryModel: channels.movieCategoriesModel
                        current: root.currentCategory
                        onCategorySelected: function(name) { root.setCategory(name) }
                    }
                }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border; visible: !root.isFullscreen }

            // Col 2: lista de filmes
            Rectangle {
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                visible: !root.isFullscreen
                color: Theme.bg

                ListView {
                    id: movieList
                    anchors.fill: parent
                    clip: true
                    model: channels.moviesModel
                    cacheBuffer: 400
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }

                    delegate: Rectangle {
                        id: mvRow
                        required property int index
                        required property string channelId
                        required property string name
                        required property string logoLocal
                        width: ListView.view.width
                        height: 64
                        property bool isCurrent: player.currentId === channelId
                        color: isCurrent ? Theme.panel2 : (mvMouse.containsMouse ? Theme.panel : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                            Rectangle {
                                width: 38; height: 52; radius: 5; color: Theme.panel2; clip: true
                                Image {
                                    anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; cache: true
                                    source: mvRow.logoLocal ? mvRow.logoLocal : ""
                                    visible: source != ""
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: mvRow.name
                                color: mvRow.isCurrent ? Theme.brand : Theme.text
                                font.pixelSize: 14; font.bold: mvRow.isCurrent
                                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            id: mvMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.playRow(mvRow.index)
                            onDoubleClicked: { root.playRow(mvRow.index); root.toggleFullscreen() }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: movieList.count === 0
                        text: channels.moviesModel && channels.moviesModel.filter !== ""
                              ? "Nenhum resultado." : "Selecione uma categoria"
                        color: Theme.subtext; font.pixelSize: 14
                    }
                }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border; visible: !root.isFullscreen }

            // Col 3: player + controles
            VodPlayerColumn {
                id: vodPlayer
                Layout.fillWidth: true
                Layout.fillHeight: true
                fullscreen: root.isFullscreen
                onFullscreenRequested: root.toggleFullscreen()
                onNextRequested: root.playRow(root.currentRow + 1)
                onPrevRequested: root.playRow(root.currentRow - 1)
            }
        }
    }
}
