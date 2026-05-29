import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Filmes — estilo Netflix/HBO: barra de topo + fileiras (carrosséis) de pôsteres
// por categoria. Cada fileira tem "Ver todos" (abre a grade da categoria) e há
// um botão "Ver todas as categorias" no canto superior direito. Buscar mostra
// uma grade de resultados. Clicar num pôster abre o player em tela cheia.
Item {
    id: root
    anchors.fill: parent

    property string view: "rows"     // "rows" | "grid" | "categories"
    property string search: ""
    property string selectedCat: ""
    property var    catItems: []
    property var    playQueue: []
    property int    playIdx: -1

    function openCategory(name) {
        root.selectedCat = name
        root.catItems = channels.moviesInCategory(name, 0)
        root.view = "grid"
    }
    function playFromArray(arr, idx) {
        root.playQueue = arr
        root.playIdx = idx
        if (idx >= 0 && idx < arr.length) playerOverlay.play(arr[idx].id)
    }
    function playStep(d) {
        var i = root.playIdx + d
        if (i >= 0 && i < root.playQueue.length) { root.playIdx = i; playerOverlay.play(root.playQueue[i].id) }
    }

    Connections { target: channels; function onError(m) { Window.window.notify(m) } }
    Shortcut { sequence: "Esc"; enabled: root.view !== "rows" && root.search === "" && !playerOverlay.active
        onActivated: root.view = "rows" }

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

        // Sub-cabeçalho: breadcrumb + "Ver todas as categorias"
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            Layout.leftMargin: 24; Layout.rightMargin: 24
            visible: root.search === ""
            spacing: 12

            Rectangle {
                visible: root.view !== "rows"
                width: 38; height: 38; radius: 19
                color: bkMouse.containsMouse ? Theme.panel2 : "transparent"
                Image { anchors.centerIn: parent
                    source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/back.svg"
                    sourceSize.width: 22; sourceSize.height: 22 }
                MouseArea { id: bkMouse; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: root.view = "rows" }
            }
            Text {
                text: root.view === "grid" ? root.selectedCat
                      : (root.view === "categories" ? "Todas as categorias" : "Filmes")
                color: Theme.text; font.pixelSize: 22; font.bold: true
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                visible: root.view === "rows"
                implicitWidth: vtcTxt.implicitWidth + 30; height: 38; radius: 19
                color: vtcMouse.containsMouse ? Theme.panel2 : Theme.panel
                border.color: Theme.border
                Text { id: vtcTxt; anchors.centerIn: parent; text: "Ver todas as categorias"
                    color: Theme.text; font.pixelSize: 13; font.bold: true }
                MouseArea { id: vtcMouse; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: root.view = "categories" }
            }
        }

        // ===== Carrosséis =====
        ListView {
            id: rows
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.search === "" && root.view === "rows"
            clip: true
            model: channels.movieCategoriesModel
            cacheBuffer: 800
            spacing: 20
            bottomMargin: 24
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
            delegate: Column {
                id: catRow
                required property string name
                width: rows.width
                spacing: 8
                RowLayout {
                    width: rows.width - 56
                    x: 28
                    Text { text: catRow.name; color: Theme.text; font.pixelSize: 19; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Ver todos  ›"; color: vtMouse.containsMouse ? Theme.brand : Theme.subtext
                        font.pixelSize: 13; font.bold: true
                        MouseArea { id: vtMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.openCategory(catRow.name) }
                    }
                }
                ListView {
                    id: rowList
                    property string categoryName: catRow.name
                    width: rows.width; height: 232
                    orientation: ListView.Horizontal
                    leftMargin: 28; rightMargin: 28; spacing: 14
                    clip: true; cacheBuffer: 600
                    boundsBehavior: Flickable.StopAtBounds
                    model: channels.moviesInCategory(catRow.name, 40)
                    delegate: PosterCard {
                        required property var modelData
                        required property int index
                        title: modelData.name; poster: modelData.logo
                        onClicked: root.playFromArray(channels.moviesInCategory(rowList.categoryName, 40), index)
                    }
                }
            }
            Text { anchors.centerIn: parent; visible: rows.count === 0
                text: "Carregando filmes..."; color: Theme.subtext; font.pixelSize: 15 }
        }

        // ===== Grade de uma categoria (Ver todos) =====
        GridView {
            id: catGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.search === "" && root.view === "grid"
            clip: true
            cellWidth: 168; cellHeight: 250
            leftMargin: 20; topMargin: 6
            model: root.catItems
            cacheBuffer: 800
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
            delegate: PosterCard {
                required property var modelData
                required property int index
                title: modelData.name; poster: modelData.logo
                onClicked: root.playFromArray(root.catItems, index)
            }
        }

        // ===== Índice de categorias =====
        GridView {
            id: catsView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.search === "" && root.view === "categories"
            clip: true
            cellWidth: 256; cellHeight: 84
            leftMargin: 20; topMargin: 6
            model: channels.movieCategoriesModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
            delegate: Item {
                required property string name
                required property int count
                width: catsView.cellWidth; height: catsView.cellHeight
                Rectangle {
                    anchors.fill: parent; anchors.margins: 6
                    radius: 12
                    color: ccMouse.containsMouse ? Theme.panel2 : Theme.panel
                    border.color: ccMouse.containsMouse ? Theme.brand : Theme.border
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 2
                        Text { Layout.fillWidth: true; text: name; color: Theme.text
                            font.pixelSize: 15; font.bold: true; elide: Text.ElideRight }
                        Text { text: count + " títulos"; color: Theme.subtext; font.pixelSize: 12 }
                    }
                    MouseArea { id: ccMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: root.openCategory(name) }
                }
            }
        }

        // ===== Resultados de busca =====
        GridView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.search !== ""
            clip: true
            cellWidth: 168; cellHeight: 250
            leftMargin: 20; topMargin: 6
            model: channels.moviesModel
            cacheBuffer: 800
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
            delegate: PosterCard {
                required property int index
                required property string channelId
                required property string name
                required property string logoLocal
                title: name; posterLocal: logoLocal
                onClicked: { root.playQueue = []; root.playIdx = -1; playerOverlay.play(channelId) }
            }
            Text { anchors.centerIn: parent; visible: results.count === 0
                text: "Nenhum resultado."; color: Theme.subtext; font.pixelSize: 15 }
        }
    }

    PlayerOverlay {
        id: playerOverlay
        onNextRequested: root.playStep(1)
        onPrevRequested: root.playStep(-1)
    }

    component PosterCard: Item {
        id: pc
        property string title: ""
        property string poster: ""
        property string posterLocal: ""
        signal clicked()
        width: 140; height: 232
        Column {
            anchors.fill: parent; spacing: 6
            Rectangle {
                width: parent.width; height: 196; radius: 10; color: Theme.panel; clip: true
                border.color: pcMouse.containsMouse ? Theme.brand : "transparent"; border.width: 2
                scale: pcMouse.containsMouse ? 1.05 : 1.0
                Behavior on scale { NumberAnimation { duration: 110 } }
                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: true
                    source: pc.posterLocal ? pc.posterLocal : (pc.poster ? pc.poster : ""); visible: source != "" }
                Image { anchors.centerIn: parent; visible: !pc.posterLocal && !pc.poster
                    source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/movie.svg"
                    sourceSize.width: 40; sourceSize.height: 40; opacity: 0.4 }
            }
            Text { width: parent.width; text: pc.title; color: Theme.textDim
                font.pixelSize: 12; elide: Text.ElideRight; maximumLineCount: 2
                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
        }
        MouseArea { id: pcMouse; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor; onClicked: pc.clicked() }
    }
}
