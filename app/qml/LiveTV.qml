import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// TV ao Vivo — redesign moderno (estilo TiViMate/Pluto): barra de topo +
// categorias + lista de canais com PROGRAMA ATUAL e barra de progresso (EPG) +
// coluna do player com EPG agora/a seguir. O EPG é mantido e fica em destaque.
Item {
    id: root
    anchors.fill: parent
    focus: true

    property string currentCategory: ""
    property string numberBuffer: ""
    property bool favTick: false
    property int epgTick: 0     // incrementado p/ forçar reavaliação do EPG nas linhas

    readonly property bool isFullscreen: Window.window && Window.window.visibility === Window.FullScreen
    function toggleFullscreen() {
        var w = Window.window
        w.visibility = (w.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
    }

    property var epgList: []
    function refreshEpg() {
        var key = player.currentTvgId ? player.currentTvgId : player.currentId
        epgList = key ? epg.upcoming(key, 6) : []
        root.epgTick++          // atualiza programa atual das linhas de canal
    }

    function selectFirstCategoryIfNeeded() {
        if (root.currentCategory === "" && channels.liveCategoriesModel.count > 0) {
            var name = channels.liveCategoriesModel.data(
                channels.liveCategoriesModel.index(0, 0), Qt.UserRole + 1)
            if (name) root.setCategory(name)
        }
    }
    function setCategory(name) {
        root.currentCategory = name
        channels.model.categoryFilter = name
    }

    Component.onCompleted: {
        forceActiveFocus()
        channels.model.filter = ""
        selectFirstCategoryIfNeeded()
        refreshEpg()
    }
    Connections {
        target: channels
        function onListReady(n) { Window.window.notify(n + " canais carregados"); selectFirstCategoryIfNeeded() }
        function onError(m) { Window.window.notify(m) }
    }
    Connections { target: player; function onCurrentChanged() { refreshEpg() } }
    Timer { interval: 15000; running: true; repeat: true; onTriggered: refreshEpg() }

    Keys.onPressed: function(e) {
        if (e.key === Qt.Key_F11) { toggleFullscreen(); e.accepted = true }
        else if (e.key === Qt.Key_Escape) { if (root.isFullscreen) toggleFullscreen(); e.accepted = true }
        else if (e.key === Qt.Key_Up)   { player.prev(); e.accepted = true }
        else if (e.key === Qt.Key_Down) { player.next(); e.accepted = true }
        else if (e.key >= Qt.Key_0 && e.key <= Qt.Key_9) {
            numberBuffer += (e.key - Qt.Key_0); numberEntry.visible = true; numberTimer.restart(); e.accepted = true
        }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (numberBuffer.length > 0) { player.playNumber(parseInt(numberBuffer)); numberBuffer=""; numberEntry.visible=false }
            e.accepted = true
        }
    }
    Timer {
        id: numberTimer; interval: 1500
        onTriggered: { if (numberBuffer.length>0) player.playNumber(parseInt(numberBuffer)); numberBuffer=""; numberEntry.visible=false }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            id: topNav
            Layout.fillWidth: true
            visible: !root.isFullscreen
            active: "live"
            onTabClicked: function(key) {
                if (key === "home")         { mpv.command(["stop"]); app.navigate("home") }
                else if (key === "movies")  { mpv.command(["stop"]); app.navigate("movies") }
                else if (key === "series")  { mpv.command(["stop"]); app.navigate("series") }
                else if (key === "profile") { mpv.command(["stop"]); app.navigate("settings") }
            }
            onSearchTextChanged: channels.model.filter = topNav.searchText
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
                categoryModel: channels.liveCategoriesModel
                current: root.currentCategory
                onCategorySelected: function(name) { root.setCategory(name) }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border; visible: !root.isFullscreen }

            // Col 2: canais (com EPG do programa atual)
            Rectangle {
                Layout.preferredWidth: 400
                Layout.fillHeight: true
                visible: !root.isFullscreen
                color: Theme.bg

                ListView {
                    id: chList
                    anchors.fill: parent
                    clip: true
                    model: channels.model
                    cacheBuffer: 400
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }

                    delegate: Rectangle {
                        id: chRow
                        required property string channelId
                        required property string tvgId
                        required property string name
                        required property int number
                        required property string logoLocal
                        required property bool isCurrent
                        width: ListView.view.width
                        height: 66
                        color: isCurrent ? Theme.panel2 : (chMouse.containsMouse ? Theme.panel : "transparent")

                        // Programa atual (reavaliado quando epgTick muda)
                        property string prog: (root.epgTick, tvgId ? epg.currentTitle(tvgId) : "")
                        property real progPct: (root.epgTick, tvgId ? epg.currentProgress(tvgId) : 0)

                        Rectangle { width: 3; height: parent.height; color: Theme.brand; visible: chRow.isCurrent }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14; anchors.rightMargin: 12; spacing: 12
                            Text {
                                text: chRow.number; color: chRow.isCurrent ? Theme.brand : Theme.subtext
                                font.pixelSize: 13; Layout.preferredWidth: 38
                            }
                            Rectangle {
                                width: 40; height: 40; radius: 6; color: Theme.panel2; clip: true
                                Image {
                                    anchors.fill: parent; anchors.margins: 2; fillMode: Image.PreserveAspectFit
                                    asynchronous: true; cache: true
                                    source: chRow.logoLocal ? chRow.logoLocal : ""
                                    visible: source != ""
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                Text {
                                    Layout.fillWidth: true
                                    text: chRow.name
                                    color: chRow.isCurrent ? Theme.brand : Theme.text
                                    font.pixelSize: 14; font.bold: true; elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: chRow.prog !== ""
                                    text: chRow.prog
                                    color: Theme.subtext; font.pixelSize: 12; elide: Text.ElideRight
                                }
                            }
                        }
                        // Barra de progresso do programa atual
                        Rectangle {
                            anchors.bottom: parent.bottom; anchors.left: parent.left
                            width: parent.width * Math.max(0, Math.min(1, chRow.progPct))
                            height: 2; color: Theme.brand; visible: chRow.progPct > 0
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border; opacity: 0.5 }

                        MouseArea {
                            id: chMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: player.playById(chRow.channelId)
                            onDoubleClicked: { player.playById(chRow.channelId); root.toggleFullscreen() }
                        }
                    }
                }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border; visible: !root.isFullscreen }

            // Col 3: player + EPG agora/a seguir + botões
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.bg

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.isFullscreen ? 0 : 16
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.isFullscreen ? root.height : width * 9 / 16
                        color: "black"
                        radius: root.isFullscreen ? 0 : 10
                        clip: true

                        MpvPlayer {
                            id: mpv
                            anchors.fill: parent
                            visible: mpv.playing
                            Component.onCompleted: player.attach(mpv)
                            onVideoDoubleClicked: root.toggleFullscreen()
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !player.currentId || player.currentId === ""
                            text: "Selecione um canal"; color: "#a0a8b8"; font.pixelSize: 18
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: mpv.buffering && player.currentId && player.currentId !== "" && !player.hasError
                            text: "Carregando..."; color: "white"; font.pixelSize: 16
                        }
                        Column {
                            anchors.centerIn: parent
                            visible: player.hasError
                            spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: "Canal indisponível"; color: "white"; font.pixelSize: 18; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: "O servidor recusou a conexão. Tente outro canal."
                                color: "#a0a8b8"; font.pixelSize: 13 }
                        }
                        MouseArea {
                            anchors.fill: parent; acceptedButtons: Qt.LeftButton
                            onDoubleClicked: root.toggleFullscreen()
                            onClicked: root.forceActiveFocus()
                        }
                    }

                    // Nome do canal + programa atual
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: !root.isFullscreen
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: player.currentName ? player.currentName : ""
                            color: Theme.text; font.pixelSize: 22; font.bold: true; elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            property string nowKey: player.currentTvgId ? player.currentTvgId : ""
                            visible: text !== ""
                            text: (root.epgTick, nowKey ? epg.currentTitle(nowKey) : "")
                            color: Theme.brand; font.pixelSize: 14; elide: Text.ElideRight
                        }
                    }

                    // EPG agora/a seguir
                    Text {
                        visible: !root.isFullscreen && root.epgList.length > 0
                        text: "Programação"; color: Theme.subtext; font.pixelSize: 12; font.bold: true
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.isFullscreen
                        clip: true
                        model: root.epgList
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { }
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 40
                            color: modelData.current ? Theme.brandSoft : "transparent"
                            radius: 6
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 14
                                Text {
                                    text: modelData.times
                                    color: modelData.current ? Theme.brand : Theme.subtext
                                    font.pixelSize: 12; font.bold: modelData.current
                                    Layout.preferredWidth: 130
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: modelData.current ? Theme.text : Theme.textDim
                                    font.pixelSize: 13; font.bold: modelData.current; elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Botões
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !root.isFullscreen
                        spacing: 12
                        Item { Layout.fillWidth: true }
                        PillButton {
                            label: (root.favTick, player.currentId && channels.isFavorite(player.currentId))
                                   ? "Remover dos Favoritos" : "Adicionar aos Favoritos"
                            enabled: player.currentId && player.currentId !== ""
                            onClicked: { channels.toggleFavorite(player.currentId); root.favTick = !root.favTick }
                        }
                        PillButton { label: "Procurar"; onClicked: topNav.focusSearch() }
                        PillButton { label: "Tela cheia"; enabled: player.currentId !== ""
                            onClicked: root.toggleFullscreen() }
                    }
                }

                Rectangle {
                    id: numberEntry; visible: false
                    anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 24
                    width: 90; height: 56; radius: 10; color: "#cc000000"; z: 40
                    Text { anchors.centerIn: parent; text: root.numberBuffer; color: "white"; font.pixelSize: 26; font.bold: true }
                }
            }
        }
    }

    component PillButton: Rectangle {
        id: pill
        property string label: ""
        property bool enabled: true
        signal clicked()
        implicitWidth: pillText.implicitWidth + 36
        implicitHeight: 44
        radius: 22
        color: !enabled ? Theme.panel2 : (pillMouse.containsMouse ? Theme.brand2 : Theme.brand)
        opacity: enabled ? 1.0 : 0.5
        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label; color: Theme.buttonText
            font.pixelSize: 14; font.bold: true
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: pill.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (pill.enabled) pill.clicked()
        }
    }
}
