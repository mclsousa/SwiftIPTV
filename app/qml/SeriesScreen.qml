import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Séries — estilo Netflix/HBO: barra de topo + carrosséis de séries por
// categoria. Clicar numa série abre os DETALHES (capa + seletor de temporada +
// lista de episódios com miniatura). Clicar num episódio abre o player.
Item {
    id: root
    anchors.fill: parent

    property string mode: "browse"     // "browse" | "detail"
    property string search: ""
    property var    seriesResults: []

    // Detalhe
    property string selCategory: ""
    property string selSeries: ""
    property var    seasonsList: []
    property int    selSeason: 0
    property var    episodeList: []
    property string selPoster: ""
    property int    playIdx: -1

    function openDetail(cat, name, poster) {
        root.selCategory = cat
        root.selSeries = name
        root.selPoster = poster ? poster : ""
        root.seasonsList = channels.seasonsOf(cat, name)
        root.selSeason = root.seasonsList.length > 0 ? root.seasonsList[0].season : 0
        loadEpisodes()
        root.mode = "detail"
    }
    function loadEpisodes() {
        root.episodeList = channels.episodesOf(root.selCategory, root.selSeries, root.selSeason)
        root.playIdx = -1
    }
    function selectSeason(s) { root.selSeason = s; loadEpisodes() }
    function playEp(idx) {
        if (idx < 0 || idx >= root.episodeList.length) return
        root.playIdx = idx
        var ep = root.episodeList[idx]
        playerOverlay.infoText = root.selSeries + "  •  T" + root.selSeason + " E" + ep.episode
        playerOverlay.play(ep.id)
    }
    function playStep(d) { root.playEp(root.playIdx + d) }

    Connections {
        target: channels
        function onError(m) { Window.window.notify(m) }
    }
    Shortcut { sequence: "Esc"; enabled: root.mode === "detail" && !playerOverlay.active
        onActivated: root.mode = "browse" }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            id: topBar
            Layout.fillWidth: true
            active: "series"
            onTabClicked: function(key) {
                if (playerOverlay.active) playerOverlay.stop()
                if (key === "home")         app.navigate("home")
                else if (key === "live")    app.navigate("player")
                else if (key === "movies")  app.navigate("movies")
                else if (key === "profile") app.navigate("settings")
            }
            onSearchTextChanged: {
                root.search = topBar.searchText
                root.seriesResults = channels.searchSeries(topBar.searchText, 80)
                if (root.search !== "") root.mode = "browse"
            }
        }

        // ====== BROWSE: carrosséis de séries ======
        ListView {
            id: rows
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.mode === "browse" && root.search === ""
            clip: true
            model: channels.seriesCategoriesModel
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
                Text { x: 28; text: catRow.name; color: Theme.text; font.pixelSize: 19; font.bold: true }
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
                    model: channels.seriesInCategory(catRow.name)
                    delegate: SeriesCard {
                        required property var modelData
                        title: modelData.name
                        poster: modelData.poster
                        onClicked: root.openDetail(rowList.categoryName, modelData.name, modelData.poster)
                    }
                }
            }
            Text { anchors.centerIn: parent; visible: rows.count === 0
                text: "Carregando séries..."; color: Theme.subtext; font.pixelSize: 15 }
        }

        // ====== BUSCA: grade de resultados ======
        GridView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.mode === "browse" && root.search !== ""
            clip: true
            cellWidth: 168; cellHeight: 250
            leftMargin: 20; topMargin: 18
            model: root.seriesResults
            cacheBuffer: 800
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
            delegate: SeriesCard {
                required property var modelData
                title: modelData.name
                poster: modelData.poster
                onClicked: root.openDetail(modelData.category, modelData.name, modelData.poster)
            }
            Text { anchors.centerIn: parent; visible: results.count === 0
                text: "Nenhuma série encontrada."; color: Theme.subtext; font.pixelSize: 15 }
        }

        // ====== DETALHE: capa + temporadas + episódios ======
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.mode === "detail"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                // Cabeçalho: voltar + poster + título + temporadas
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    Rectangle {
                        width: 150; height: 222; radius: 12; color: Theme.panel; clip: true
                        Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            source: root.selPoster ? root.selPoster : ""; visible: source != "" }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 12

                        RowLayout {
                            spacing: 10
                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: dbMouse.containsMouse ? Theme.panel2 : "transparent"
                                Image { anchors.centerIn: parent
                                    source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/back.svg"
                                    sourceSize.width: 22; sourceSize.height: 22 }
                                MouseArea { id: dbMouse; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor; onClicked: root.mode = "browse" }
                            }
                            Text { Layout.fillWidth: true; text: root.selSeries; color: Theme.text
                                font.pixelSize: 26; font.bold: true; elide: Text.ElideRight }
                        }

                        Text {
                            text: root.seasonsList.length + (root.seasonsList.length === 1 ? " temporada" : " temporadas")
                            color: Theme.subtext; font.pixelSize: 14
                        }

                        // Seletor de temporadas
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: root.seasonsList
                                delegate: Rectangle {
                                    required property var modelData
                                    width: chTxt.implicitWidth + 26; height: 34; radius: 17
                                    property bool sel: modelData.season === root.selSeason
                                    color: sel ? Theme.brand : Theme.panel2
                                    border.color: sel ? Theme.brand : Theme.border
                                    Text { id: chTxt; anchors.centerIn: parent
                                        text: "Temporada " + modelData.season
                                        color: sel ? Theme.buttonText : Theme.text
                                        font.pixelSize: 13; font.bold: sel }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectSeason(modelData.season) }
                                }
                            }
                        }
                    }
                }

                // Episódios
                ListView {
                    id: epList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.episodeList
                    spacing: 10
                    cacheBuffer: 600
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: epList.width
                        height: 92
                        radius: 10
                        color: epMouse.containsMouse ? Theme.panel2 : Theme.panel
                        border.color: player.currentId === modelData.id ? Theme.brand : Theme.border
                        border.width: player.currentId === modelData.id ? 2 : 1
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12; spacing: 14
                            Rectangle {
                                width: 124; height: 68; radius: 6; color: Theme.bg; clip: true
                                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; cache: true
                                    source: modelData.logo ? modelData.logo : ""; visible: source != "" }
                                // Play sobre a miniatura
                                Rectangle {
                                    anchors.centerIn: parent; width: 34; height: 34; radius: 17
                                    color: "#aa000000"; visible: epMouse.containsMouse
                                    Image { anchors.centerIn: parent
                                        source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/play.svg"
                                        sourceSize.width: 20; sourceSize.height: 20 }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Episódio " + modelData.episode
                                    color: player.currentId === modelData.id ? Theme.brand : Theme.text
                                    font.pixelSize: 16; font.bold: true }
                                Text { Layout.fillWidth: true; text: modelData.name
                                    color: Theme.subtext; font.pixelSize: 12; elide: Text.ElideRight }
                            }
                        }
                        MouseArea { id: epMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.playEp(index) }
                    }
                }
            }
        }
    }

    // Player tela cheia
    PlayerOverlay {
        id: playerOverlay
        onNextRequested: root.playStep(1)
        onPrevRequested: root.playStep(-1)
    }

    // Cartão de série (capa + título)
    component SeriesCard: Item {
        id: sc
        property string title: ""
        property string poster: ""
        signal clicked()
        width: 140; height: 232
        Column {
            anchors.fill: parent; spacing: 6
            Rectangle {
                width: parent.width; height: 196; radius: 10; color: Theme.panel; clip: true
                border.color: scMouse.containsMouse ? Theme.brand : "transparent"; border.width: 2
                scale: scMouse.containsMouse ? 1.05 : 1.0
                Behavior on scale { NumberAnimation { duration: 110 } }
                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: true
                    source: sc.poster ? sc.poster : ""; visible: source != "" }
                Image { anchors.centerIn: parent; visible: !sc.poster
                    source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/series.svg"
                    sourceSize.width: 40; sourceSize.height: 40; opacity: 0.4 }
            }
            Text { width: parent.width; text: sc.title; color: Theme.textDim
                font.pixelSize: 12; elide: Text.ElideRight; maximumLineCount: 2
                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
        }
        MouseArea { id: scMouse; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor; onClicked: sc.clicked() }
    }
}
