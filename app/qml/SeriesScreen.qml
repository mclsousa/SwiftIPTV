import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Tela de Séries em 3 colunas:
//   categorias  |  série -> temporada -> episódios  |  player + controles
// A coluna do meio navega: lista de séries -> (clica) -> temporadas + episódios.
Item {
    id: root
    anchors.fill: parent
    focus: true

    property string currentCategory: ""
    property var    seriesList: []
    property string selectedSeries: ""
    property var    seasonsList: []
    property int    selectedSeason: 0
    property var    episodeList: []
    property int    currentEpRow: -1

    readonly property bool isFullscreen: Window.window && Window.window.visibility === Window.FullScreen
    function toggleFullscreen() {
        var w = Window.window
        w.visibility = (w.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
    }

    function setCategory(name) {
        root.currentCategory = name
        root.selectedSeries = ""
        root.seriesList = channels.seriesInCategory(name)
    }
    function openSeries(name) {
        root.selectedSeries = name
        root.seasonsList = channels.seasonsOf(root.currentCategory, name)
        root.selectedSeason = root.seasonsList.length > 0 ? root.seasonsList[0].season : 0
        loadEpisodes()
    }
    function loadEpisodes() {
        root.episodeList = channels.episodesOf(root.currentCategory, root.selectedSeries, root.selectedSeason)
        root.currentEpRow = -1
    }
    function selectSeason(s) { root.selectedSeason = s; loadEpisodes() }
    function playEp(row) {
        if (row < 0 || row >= root.episodeList.length) return
        root.currentEpRow = row
        var ep = root.episodeList[row]
        player.playById(ep.id)
        vodPlayer.infoText = root.selectedSeries + "  •  T" + root.selectedSeason + " E" + ep.episode
    }
    function selectFirstCategoryIfNeeded() {
        if (root.currentCategory === "" && channels.seriesCategoriesModel.count > 0) {
            var name = channels.seriesCategoriesModel.data(
                channels.seriesCategoriesModel.index(0, 0), Qt.UserRole + 1)
            if (name) root.setCategory(name)
        }
    }

    Component.onCompleted: { forceActiveFocus(); selectFirstCategoryIfNeeded() }
    Connections {
        target: channels
        function onListReady(n) { root.setCategory(root.currentCategory); selectFirstCategoryIfNeeded() }
        function onError(m) { Window.window.notify(m) }
    }
    Keys.onPressed: function(e) {
        if (e.key === Qt.Key_F11) { toggleFullscreen(); e.accepted = true }
        else if (e.key === Qt.Key_Escape) {
            if (root.isFullscreen) toggleFullscreen()
            else if (root.selectedSeries !== "") root.selectedSeries = ""
            e.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopNav {
            id: topNav
            Layout.fillWidth: true
            visible: !root.isFullscreen
            active: "series"
            onTabClicked: function(key) {
                vodPlayer.stop()
                if (key === "home")        app.navigate("home")
                else if (key === "live")   app.navigate("player")
                else if (key === "movies") app.navigate("movies")
            }
            // Busca filtra a lista de séries da categoria atual (client-side).
            onSearchTextChanged: root.filterSeries(topNav.searchText)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Col 1: categorias
            CategorySidebar {
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                visible: !root.isFullscreen
                categoryModel: channels.seriesCategoriesModel
                current: root.currentCategory
                onCategorySelected: function(name) { root.setCategory(name) }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border; visible: !root.isFullscreen }

            // Col 2: séries  /  temporadas + episódios
            Rectangle {
                Layout.preferredWidth: 380
                Layout.fillHeight: true
                visible: !root.isFullscreen
                color: Theme.bg

                // --- Nível 1: lista de séries ---
                ListView {
                    id: seriesView
                    anchors.fill: parent
                    visible: root.selectedSeries === ""
                    clip: true
                    model: root.seriesList
                    cacheBuffer: 400
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 70
                        color: srMouse.containsMouse ? Theme.panel : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                            Rectangle {
                                width: 40; height: 56; radius: 5; color: Theme.panel2; clip: true
                                Image {
                                    anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; cache: true
                                    source: modelData.poster ? modelData.poster : ""
                                    visible: source != ""
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Text { Layout.fillWidth: true; text: modelData.name; color: Theme.text
                                    font.pixelSize: 14; font.bold: true; elide: Text.ElideRight }
                                Text { text: modelData.seasons + (modelData.seasons === 1 ? " temporada" : " temporadas")
                                       + "  •  " + modelData.episodes + " ep"
                                    color: Theme.subtext; font.pixelSize: 12 }
                            }
                            Text { text: "›"; color: Theme.subtext; font.pixelSize: 22 }
                        }
                        MouseArea { id: srMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.openSeries(modelData.name) }
                    }
                    Text {
                        anchors.centerIn: parent; visible: seriesView.count === 0
                        text: "Selecione uma categoria"; color: Theme.subtext; font.pixelSize: 14
                    }
                }

                // --- Nível 2: temporadas + episódios ---
                ColumnLayout {
                    anchors.fill: parent
                    visible: root.selectedSeries !== ""
                    spacing: 0

                    // Cabeçalho: voltar + nome da série
                    Rectangle {
                        Layout.fillWidth: true; height: 48; color: Theme.panel
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 12; spacing: 8
                            Rectangle {
                                width: 36; height: 36; radius: 18
                                color: backMouse.containsMouse ? Theme.panel2 : "transparent"
                                Image { anchors.centerIn: parent
                                    source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/back.svg"
                                    sourceSize.width: 20; sourceSize.height: 20 }
                                MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor; onClicked: root.selectedSeries = "" }
                            }
                            Text { Layout.fillWidth: true; text: root.selectedSeries; color: Theme.text
                                font.pixelSize: 15; font.bold: true; elide: Text.ElideRight }
                        }
                    }

                    // Seletor de temporadas
                    Flickable {
                        Layout.fillWidth: true; Layout.preferredHeight: 46
                        contentWidth: seasonRow.width; clip: true
                        Row {
                            id: seasonRow
                            height: 46; spacing: 8; leftPadding: 10; rightPadding: 10
                            Repeater {
                                model: root.seasonsList
                                delegate: Rectangle {
                                    required property var modelData
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: chipText.implicitWidth + 24; height: 32; radius: 16
                                    property bool sel: modelData.season === root.selectedSeason
                                    color: sel ? Theme.brand : Theme.panel2
                                    Text { id: chipText; anchors.centerIn: parent
                                        text: "Temporada " + modelData.season
                                        color: sel ? Theme.buttonText : Theme.text
                                        font.pixelSize: 12; font.bold: sel }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectSeason(modelData.season) }
                                }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                    // Episódios da temporada
                    ListView {
                        id: epView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        model: root.episodeList
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { }
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            width: ListView.view.width
                            height: 56
                            property bool isCurrent: player.currentId === modelData.id
                            color: isCurrent ? Theme.panel2 : (epMouse.containsMouse ? Theme.panel : "transparent")
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12; spacing: 10
                                Text { text: modelData.episode; color: isCurrent ? Theme.brand : Theme.subtext
                                    font.pixelSize: 14; font.bold: true; Layout.preferredWidth: 30 }
                                Text { Layout.fillWidth: true; text: "Episódio " + modelData.episode
                                    color: isCurrent ? Theme.brand : Theme.text; font.pixelSize: 14
                                    font.bold: isCurrent; elide: Text.ElideRight }
                            }
                            MouseArea { id: epMouse; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.playEp(index)
                                onDoubleClicked: { root.playEp(index); root.toggleFullscreen() } }
                        }
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
                onNextRequested: root.playEp(root.currentEpRow + 1)
                onPrevRequested: root.playEp(root.currentEpRow - 1)
            }
        }
    }

    // Filtra a lista de séries da categoria atual pelo texto da busca.
    function filterSeries(text) {
        var all = channels.seriesInCategory(root.currentCategory)
        if (!text || text === "") { root.seriesList = all; return }
        var t = text.toLowerCase()
        var out = []
        for (var i = 0; i < all.length; ++i)
            if (all[i].name.toLowerCase().indexOf(t) >= 0) out.push(all[i])
        root.seriesList = out
    }
}
