import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Navegador de VOD reutilizável (Filmes / Séries) — Fase 5/6 do redesign.
// Layout do modelo: barra de topo + coluna de categorias à esquerda +
// grade de pôsteres à direita. Clicar num pôster abre um player inline
// (overlay) sobre a grade; o botão Voltar do overlay retorna à grade.
//
// Usado por MoviesScreen.qml e SeriesScreen.qml passando os modelos certos.
Item {
    id: root
    anchors.fill: parent
    focus: true

    // --- Parâmetros (definidos por MoviesScreen / SeriesScreen) ---
    property string tabKey: "movies"            // "movies" | "series"
    property string kindLabel: "Filmes"
    property var listModel: null                // ChannelListModel (movie/series)
    property var categoryModel: null            // CategoryListModel
    property string fallbackIcon: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/movie.svg"

    property string currentCategory: ""
    property bool playing: false                // overlay de player visível?

    function setCategory(name) {
        root.currentCategory = name
        if (listModel) listModel.categoryFilter = name
    }
    function selectFirstCategoryIfNeeded() {
        if (root.currentCategory === "" && categoryModel && categoryModel.count > 0) {
            var name = categoryModel.data(categoryModel.index(0, 0), Qt.UserRole + 1) // NameRole
            if (name) root.setCategory(name)
        }
    }
    function play(id) {
        // O vodMpv já foi attachado no Component.onCompleted do MpvPlayer abaixo
        // (NÃO chamar attach() de novo aqui — duplicaria as conexões de signal
        // do StreamPlayer e dispararia reloads em dobro).
        root.playing = true
        player.playById(id)
    }
    function closePlayer() {
        vodMpv.command(["stop"])
        root.playing = false
    }

    Component.onCompleted: {
        forceActiveFocus()
        if (listModel) listModel.filter = ""
        selectFirstCategoryIfNeeded()
    }
    Connections {
        target: channels
        function onListReady(n) { selectFirstCategoryIfNeeded() }
        function onError(m) { Window.window.notify(m) }
    }

    Keys.onPressed: function(e) {
        if (e.key === Qt.Key_Escape && root.playing) { root.closePlayer(); e.accepted = true }
    }

    // ==================== Navegação (grade) ====================
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopNav {
            id: topNav
            Layout.fillWidth: true
            active: root.tabKey
            onTabClicked: function(key) {
                if (root.playing) root.closePlayer()
                vodMpv.command(["stop"])
                if (key === "home")        app.navigate("home")
                else if (key === "live")   app.navigate("player")
                else if (key === "movies" && root.tabKey !== "movies") app.navigate("movies")
                else if (key === "series" && root.tabKey !== "series") app.navigate("series")
            }
            onSearchTextChanged: if (root.listModel) root.listModel.filter = topNav.searchText
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Coluna 1: categorias
            CategorySidebar {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                categoryModel: root.categoryModel
                current: root.currentCategory
                onCategorySelected: function(name) { root.setCategory(name) }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border }

            // Coluna 2: grade de pôsteres
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.bg

                GridView {
                    id: grid
                    anchors.fill: parent
                    anchors.margins: 16
                    clip: true
                    cellWidth: 172
                    cellHeight: 268
                    model: root.listModel
                    cacheBuffer: 600
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }

                    delegate: Item {
                        id: poster
                        required property string channelId
                        required property string name
                        required property string logoLocal
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: 12
                            color: posterMouse.containsMouse ? Theme.panel2 : Theme.panel
                            border.color: posterMouse.containsMouse ? Theme.brand : Theme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                // Pôster
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: Theme.panel2
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true; cache: true
                                        source: poster.logoLocal ? poster.logoLocal : ""
                                        visible: source != ""
                                    }
                                    // Placeholder quando não há pôster
                                    Image {
                                        anchors.centerIn: parent
                                        visible: !poster.logoLocal
                                        source: root.fallbackIcon
                                        sourceSize.width: 48; sourceSize.height: 48
                                        opacity: 0.5
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    text: poster.name
                                    color: Theme.text
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                            MouseArea {
                                id: posterMouse
                                anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.play(poster.channelId)
                            }
                        }
                    }

                    // Estado vazio
                    Text {
                        anchors.centerIn: parent
                        visible: grid.count === 0
                        text: root.listModel && root.listModel.filter !== ""
                              ? "Nenhum resultado para a busca."
                              : "Carregando " + root.kindLabel.toLowerCase() + "..."
                        color: Theme.subtext; font.pixelSize: 15
                    }
                }
            }
        }
    }

    // ==================== Overlay: player inline ====================
    Rectangle {
        id: overlay
        anchors.fill: parent
        z: 50
        visible: root.playing
        color: "black"

        // Vídeo
        MpvPlayer {
            id: vodMpv
            anchors.fill: parent
            visible: vodMpv.playing
            Component.onCompleted: player.attach(vodMpv)
            onVideoDoubleClicked: root.closePlayer()
        }

        // Estados (buffering / erro)
        Text {
            anchors.centerIn: parent
            visible: vodMpv.buffering && !player.hasError
            text: "Carregando..."; color: "white"; font.pixelSize: 16
        }
        Column {
            anchors.centerIn: parent
            visible: player.hasError
            spacing: 8
            Text { anchors.horizontalCenter: parent.horizontalCenter
                text: "Conteúdo indisponível"; color: "white"; font.pixelSize: 18; font.bold: true }
            Text { anchors.horizontalCenter: parent.horizontalCenter
                text: "O servidor recusou a conexão. Tente outro título."
                color: "#a0a8b8"; font.pixelSize: 13 }
        }

        // Barra superior do overlay: voltar + título
        Rectangle {
            id: overlayTop
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 56
            color: "#cc000000"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 16; spacing: 12
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: backMouse.containsMouse ? "#33ffffff" : "transparent"
                    Image {
                        anchors.centerIn: parent
                        source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/back.svg"
                        sourceSize.width: 24; sourceSize.height: 24; smooth: true
                    }
                    MouseArea {
                        id: backMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.closePlayer()
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: player.currentName ? player.currentName : ""
                    color: "white"; font.pixelSize: 18; font.bold: true
                    elide: Text.ElideRight
                }
            }
        }
    }
}
