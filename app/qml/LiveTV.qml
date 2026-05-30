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
    opacity: 0
    NumberAnimation on opacity { from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic }

    // Modo "Favoritos": mesma tela, mas a coluna de canais usa a lista de
    // favoritos e a barra de categorias some.
    property bool favMode: app.screen === "favorites"
    readonly property var activeModel: favMode ? channels.favoritesModel : channels.model

    property string currentCategory: ""
    property string numberBuffer: ""
    property bool favTick: false
    property int epgTick: 0     // incrementado p/ forçar reavaliação do EPG nas linhas
    // Guia completo (botão EPG)
    property bool epgFullOpen: false
    property var  epgFullList: []
    function openFullEpg() {
        var key = player.currentTvgId ? player.currentTvgId : player.currentId
        root.epgFullList = key ? epg.upcoming(key, 200) : []
        root.epgFullOpen = true
    }

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
        root.activeModel.filter = ""
        if (!favMode) selectFirstCategoryIfNeeded()
        refreshEpg()
    }
    // Alternar player<->favoritos não recria a tela (mesmo Loader source): reage
    // à troca de modo p/ limpar a busca e (re)selecionar a 1ª categoria ao vivo.
    onFavModeChanged: {
        topNav.searchText = ""
        root.activeModel.filter = ""
        if (!favMode) selectFirstCategoryIfNeeded()
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
            active: root.favMode ? "favorites" : "live"
            onTabClicked: function(key) {
                if (key === active) return        // já está nesta aba
                // player.stop() (não "mpv stop" cru): limpa o canal atual e
                // desliga o watchdog. Sem isso, ao trocar p/ Favoritos (mesma
                // tela) o currentId ficava setado -> overlay "Carregando" preso
                // e o watchdog religava o canal antigo em 6s.
                player.stop()
                if (key === "home")           app.navigate("home")
                else if (key === "live")      app.navigate("player")
                else if (key === "favorites") app.navigate("favorites")
                else if (key === "movies")    app.navigate("movies")
                else if (key === "series")    app.navigate("series")
                else if (key === "profile")   app.navigate("settings")
            }
            onSearchTextChanged: root.activeModel.filter = topNav.searchText
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Col 1: categorias (oculta no modo Favoritos)
            CategorySidebar {
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                visible: !root.isFullscreen && !root.favMode
                categoryModel: channels.liveCategoriesModel
                current: root.currentCategory
                onCategorySelected: function(name) { root.setCategory(name) }
                onLockedCategoryClicked: function(name) { pinDialog.openFor(name) }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border
                visible: !root.isFullscreen && !root.favMode }

            // Col 2: canais (com EPG do programa atual)
            Rectangle {
                Layout.preferredWidth: 400
                Layout.fillHeight: true
                visible: !root.isFullscreen
                color: Theme.bg

                // Estado vazio do modo Favoritos
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 10
                    visible: root.favMode && chList.count === 0
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/star.svg"
                        sourceSize.width: 44; sourceSize.height: 44; opacity: 0.5
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Nenhum favorito ainda"; color: Theme.text
                        font.pixelSize: 16; font.bold: true
                    }
                    Text {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Abra um canal em TV ao Vivo e toque em \"Favoritos\" para salvá-lo aqui."
                        color: Theme.subtext; font.pixelSize: 13
                    }
                }

                ListView {
                    id: chList
                    anchors.fill: parent
                    clip: true
                    model: root.activeModel
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
                                width: 44; height: 44; radius: 10
                                color: Theme.panel2; border.color: Theme.border; border.width: 1
                                clip: true
                                Image {
                                    anchors.fill: parent; anchors.margins: 4; fillMode: Image.PreserveAspectFit
                                    asynchronous: true; cache: true
                                    smooth: true; mipmap: true
                                    sourceSize.width: 96; sourceSize.height: 96
                                    source: chRow.logoLocal ? chRow.logoLocal : ""
                                    visible: source != ""
                                }
                                // Fallback elegante quando o canal não tem logo
                                Image {
                                    anchors.centerIn: parent
                                    visible: !chRow.logoLocal
                                    source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/tv.svg"
                                    sourceSize.width: 20; sourceSize.height: 20; opacity: 0.40
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
                        Column {
                            anchors.centerIn: parent
                            visible: !player.currentId || player.currentId === ""
                            spacing: 12
                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/tv.svg"
                                sourceSize.width: 56; sourceSize.height: 56; opacity: 0.5
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Selecione um canal"; color: "#a0a8b8"; font.pixelSize: 17
                            }
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

                    // EPG agora/a seguir (o botão EPG abre o guia completo)
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

                    // Botões só-ícone (estilo ghost: viram botão no hover; tooltip com o nome)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !root.isFullscreen
                        spacing: 4
                        Item { Layout.fillWidth: true }
                        AppButton {
                            kind: "ghost"; iconSize: 22
                            enabled: player.currentId !== ""
                            tooltip: (root.favTick, player.currentId && channels.isFavorite(player.currentId))
                                     ? "Remover dos favoritos" : "Adicionar aos favoritos"
                            iconSource: (root.favTick, player.currentId && channels.isFavorite(player.currentId))
                                        ? "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/star_filled.svg"
                                        : "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/star.svg"
                            onClicked: { channels.toggleFavorite(player.currentId); root.favTick = !root.favTick }
                        }
                        AppButton {
                            kind: "ghost"; iconSize: 22
                            enabled: player.currentId !== ""
                            tooltip: "Guia de programação (EPG)"
                            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/epg.svg"
                            onClicked: root.openFullEpg()
                        }
                        AppButton {
                            kind: "ghost"; iconSize: 22
                            enabled: player.currentId !== ""
                            tooltip: "Tela cheia"
                            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/fullscreen.svg"
                            onClicked: root.toggleFullscreen()
                        }
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

    PinDialog { id: pinDialog; onUnlocked: root.setCategory(pinDialog.category) }

    // ----- Guia completo de EPG do canal atual -----
    Rectangle {
        anchors.fill: parent
        visible: root.epgFullOpen
        z: 150
        color: "#cc000000"
        MouseArea { anchors.fill: parent; onClicked: root.epgFullOpen = false }

        Rectangle {
            id: epgPanel
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.min(parent.width * 0.42, 470)
            color: Theme.panel
            // entra deslizando da esquerda (fica longe do vídeo, que está à direita)
            x: root.epgFullOpen ? 0 : -width
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }
            MouseArea { anchors.fill: parent }   // não fecha ao clicar dentro

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 22; spacing: 12
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Image { source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/epg.svg"
                        sourceSize.width: 22; sourceSize.height: 22 }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { text: "Guia de programação"; color: Theme.text; font.pixelSize: 18; font.bold: true }
                        Text { text: player.currentName ? player.currentName : ""
                            color: Theme.subtext; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: epgX.containsMouse ? Theme.panel2 : "transparent"
                        Text { anchors.centerIn: parent; text: "×"; color: Theme.text; font.pixelSize: 22 }
                        MouseArea { id: epgX; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.epgFullOpen = false }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; model: root.epgFullList; spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width; height: 46; radius: 6
                        color: modelData.current ? Theme.brandSoft : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 14
                            Text { text: modelData.times
                                color: modelData.current ? Theme.brand : Theme.subtext
                                font.pixelSize: 13; font.bold: modelData.current; Layout.preferredWidth: 140 }
                            Text { Layout.fillWidth: true; text: modelData.title
                                color: modelData.current ? Theme.text : Theme.textDim
                                font.pixelSize: 14; font.bold: modelData.current; elide: Text.ElideRight }
                        }
                    }
                    Text { anchors.centerIn: parent; visible: root.epgFullList.length === 0
                        text: "Sem guia disponível para este canal."; color: Theme.subtext; font.pixelSize: 14 }
                }
            }
        }
    }
}
