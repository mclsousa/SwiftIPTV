import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Filmes — navegação estilo Netflix/HBO: barra de topo + fileiras (carrosséis)
// horizontais de pôsteres, uma por categoria. Buscar mostra uma grade de
// resultados. Clicar num pôster abre o player em tela cheia.
Item {
    id: root
    anchors.fill: parent

    property string search: ""
    property var    playQueue: []
    property int    playIdx: -1

    function playFromCategory(cat, idx) {
        root.playQueue = channels.moviesInCategory(cat, 60)
        root.playIdx = idx
        if (idx >= 0 && idx < root.playQueue.length)
            playerOverlay.play(root.playQueue[idx].id)
    }
    function playStep(d) {
        var i = root.playIdx + d
        if (i >= 0 && i < root.playQueue.length) {
            root.playIdx = i
            playerOverlay.play(root.playQueue[i].id)
        }
    }

    Connections {
        target: channels
        function onError(m) { Window.window.notify(m) }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            id: topBar
            Layout.fillWidth: true
            active: "movies"
            onTabClicked: function(key) {
                if (playerOverlay.active) playerOverlay.stop()
                if (key === "home")         app.navigate("home")
                else if (key === "live")    app.navigate("player")
                else if (key === "series")  app.navigate("series")
                else if (key === "profile") app.navigate("settings")
            }
            onSearchTextChanged: {
                root.search = topBar.searchText
                channels.moviesModel.categoryFilter = ""
                channels.moviesModel.filter = topBar.searchText
            }
        }

        // ---------- Carrosséis (navegação normal) ----------
        ListView {
            id: rows
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.search === ""
            clip: true
            model: channels.movieCategoriesModel
            cacheBuffer: 800
            spacing: 22
            topMargin: 18; bottomMargin: 24
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }

            delegate: Column {
                id: catRow
                required property string name
                width: rows.width
                spacing: 8

                Text {
                    x: 28
                    text: catRow.name
                    color: Theme.text; font.pixelSize: 19; font.bold: true
                }

                ListView {
                    id: rowList
                    property string categoryName: catRow.name
                    width: rows.width
                    height: 232
                    orientation: ListView.Horizontal
                    leftMargin: 28; rightMargin: 28
                    spacing: 14
                    clip: true
                    cacheBuffer: 600
                    boundsBehavior: Flickable.StopAtBounds
                    model: channels.moviesInCategory(catRow.name, 40)

                    delegate: PosterCard {
                        required property var modelData
                        required property int index
                        title: modelData.name
                        poster: modelData.logo
                        onClicked: root.playFromCategory(rowList.categoryName, index)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: rows.count === 0
                text: "Carregando filmes..."
                color: Theme.subtext; font.pixelSize: 15
            }
        }

        // ---------- Grade de resultados de busca ----------
        GridView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.search !== ""
            clip: true
            cellWidth: 168; cellHeight: 250
            leftMargin: 20; topMargin: 18
            model: channels.moviesModel
            cacheBuffer: 800
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
            delegate: PosterCard {
                required property int index
                required property string channelId
                required property string name
                required property string logoLocal
                title: name
                posterLocal: logoLocal
                onClicked: { root.playQueue = []; root.playIdx = -1; playerOverlay.play(channelId) }
            }
            Text { anchors.centerIn: parent; visible: results.count === 0
                text: "Nenhum resultado."; color: Theme.subtext; font.pixelSize: 15 }
        }
    }

    // ---------- Player tela cheia ----------
    PlayerOverlay {
        id: playerOverlay
        onNextRequested: root.playStep(1)
        onPrevRequested: root.playStep(-1)
    }

    // Cartão de pôster (capa 2:3 + título), hover com leve zoom.
    component PosterCard: Item {
        id: pc
        property string title: ""
        property string poster: ""       // URL remota
        property string posterLocal: ""  // caminho local (modelo)
        signal clicked()
        width: 140; height: 232

        Column {
            anchors.fill: parent
            spacing: 6
            Rectangle {
                id: art
                width: parent.width; height: 196
                radius: 10; color: Theme.panel; clip: true
                border.color: pcMouse.containsMouse ? Theme.brand : "transparent"
                border.width: 2
                scale: pcMouse.containsMouse ? 1.05 : 1.0
                Behavior on scale { NumberAnimation { duration: 110 } }
                Image {
                    anchors.fill: parent; anchors.margins: 0
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: true
                    source: pc.posterLocal ? pc.posterLocal : (pc.poster ? pc.poster : "")
                    visible: source != ""
                }
                Image {
                    anchors.centerIn: parent
                    visible: !pc.posterLocal && !pc.poster
                    source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/movie.svg"
                    sourceSize.width: 40; sourceSize.height: 40; opacity: 0.4
                }
            }
            Text {
                width: parent.width
                text: pc.title; color: Theme.textDim
                font.pixelSize: 12; elide: Text.ElideRight
                maximumLineCount: 2; wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
        MouseArea {
            id: pcMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: pc.clicked()
        }
    }
}
