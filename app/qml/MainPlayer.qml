import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

Item {
    id: root
    anchors.fill: parent
    focus: true

    property string currentTab: "channels"
    property string numberBuffer: ""
    property string epgTitle: ""
    property string epgTimes: ""
    property real   epgProgress: 0

    // --- Auto-hide da UI lateral + barra de botões ---
    // Em fullscreen sempre escondidos. Em modo normal, escondem após 5s
    // sem movimento de mouse; voltam ao primeiro movimento.
    property bool   autoHidden: false
    readonly property bool isFullscreen: Window.window && Window.window.visibility === Window.FullScreen
    readonly property bool uiHidden: autoHidden || isFullscreen

    function showUI() {
        autoHidden = false
        autoHideTimer.restart()
    }
    Timer {
        id: autoHideTimer
        interval: 5000        // 5 segundos sem movimento de mouse → some
        running: !root.isFullscreen
        onTriggered: root.autoHidden = true
    }
    // Captura movimento do mouse em qualquer ponto da tela sem bloquear cliques.
    HoverHandler {
        id: hoverAny
        onPointChanged: root.showUI()
    }

    function activeModel() {
        if (currentTab === "favorites") return channels.favoritesModel
        if (currentTab === "history")   return channels.historyModel
        return channels.model
    }
    function refreshEpg() {
        // EPG é casado pelo tvg-id original do M3U (que pode repetir entre
        // variantes do mesmo canal); player.currentId é o ID único de linha.
        var key = player.currentTvgId ? player.currentTvgId : player.currentId
        epgTitle = epg.currentTitle(key)
        epgTimes = epg.currentTimes(key)
        epgProgress = epg.currentProgress(key)
    }
    function toggleFullscreen() {
        var w = Window.window
        w.visibility = (w.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
    }

    Component.onCompleted: {
        forceActiveFocus()
        // Não tocamos canal automaticamente: o usuário escolhe na lista.
    }

    Connections {
        target: channels
        // Lista pronta: só registra (sem auto-play). O usuário escolhe o canal.
        function onListReady(n) { Window.window.notify(n + " canais carregados") }
        function onError(m) { Window.window.notify(m) }
    }
    Connections {
        target: player
        function onCurrentChanged() { refreshEpg(); overlay.flash() }
        function onSwitchTimed(ms) { Window.window.notify("Troca em " + ms + " ms") }
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: refreshEpg() }

    // -------- Atalhos de teclado --------
    Keys.onPressed: function(e) {
        if (e.key === Qt.Key_F11) { toggleFullscreen(); e.accepted = true }
        else if (e.key === Qt.Key_Escape) {
            if (Window.window.visibility === Window.FullScreen) toggleFullscreen()
            e.accepted = true
        }
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Left)  { player.prev(); e.accepted = true }
        else if (e.key === Qt.Key_Down || e.key === Qt.Key_Right){ player.next(); e.accepted = true }
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

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ============ PAINEL ESQUERDO ============
        Rectangle {
            id: sidebar
            Layout.preferredWidth: root.uiHidden ? 0 : 300
            Layout.fillHeight: true
            visible: Layout.preferredWidth > 0
            color: Theme.panel
            border.color: Theme.border
            // Fade suave ao esconder/mostrar.
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Busca
                Rectangle {
                    Layout.fillWidth: true; height: 56; color: Theme.panel
                    TextField {
                        id: search
                        anchors.fill: parent; anchors.margins: 10
                        placeholderText: "🔍  Buscar canal..."
                        color: Theme.text; placeholderTextColor: Theme.subtext
                        background: Rectangle { radius: 8; color: Theme.panel2; border.color: Theme.border }
                        leftPadding: 12
                        onTextChanged: root.activeModel().filter = text
                    }
                }
                // Abas
                RowLayout {
                    Layout.fillWidth: true; spacing: 0
                    Repeater {
                        model: [ {k:"channels",t:"Canais"}, {k:"favorites",t:"Favoritos"}, {k:"history",t:"Histórico"} ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; height: 38
                            color: "transparent"
                            Text { anchors.centerIn: parent; text: modelData.t
                                color: currentTab===modelData.k ? Theme.brand : Theme.subtext
                                font.pixelSize: 13; font.bold: currentTab===modelData.k }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2
                                color: currentTab===modelData.k ? Theme.brand : "transparent" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { currentTab = modelData.k; search.text=""; root.activeModel().filter="" } }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                // Lista virtualizada
                ListView {
                    id: list
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    model: root.activeModel()
                    cacheBuffer: 400
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }

                    section.property: "group"
                    section.criteria: ViewSection.FullString
                    section.delegate: Rectangle {
                        width: ListView.view.width; height: 28; color: Theme.panel2
                        required property string section
                        Text { anchors.verticalCenter: parent.verticalCenter; x: 12
                            text: section; color: Theme.subtext; font.pixelSize: 11; font.bold: true }
                    }

                    delegate: Rectangle {
                        id: row
                        width: ListView.view.width; height: 54
                        color: isCurrent ? "#243066" : (rowMouse.containsMouse ? Theme.panel2 : "transparent")
                        // Barra lateral mais grossa e indicador "▶" pra deixar claro
                        // qual canal está sendo reproduzido (várias variantes do mesmo
                        // canal têm nomes parecidos).
                        Rectangle { width: 4; height: parent.height; color: Theme.brand; visible: isCurrent }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                            Rectangle {
                                width: 32; height: 32; radius: 6; color: Theme.panel2; clip: true
                                Image {
                                    anchors.fill: parent; fillMode: Image.PreserveAspectFit
                                    asynchronous: true; cache: true
                                    source: logoLocal ? logoLocal : ""
                                    visible: source != ""
                                }
                                Text { anchors.centerIn: parent; visible: !logoLocal; text: "📺"; font.pixelSize: 14 }
                            }
                            ColumnLayout {
                                spacing: 1; Layout.fillWidth: true
                                RowLayout {
                                    spacing: 6; Layout.fillWidth: true
                                    Text {
                                        visible: isCurrent
                                        text: "▶"; color: Theme.brand
                                        font.pixelSize: 12; font.bold: true
                                    }
                                    Text { text: name; color: isCurrent ? Theme.text : "#cdd4e4"; font.pixelSize: 13
                                        elide: Text.ElideRight; Layout.fillWidth: true; font.bold: isCurrent }
                                }
                                Text {
                                    visible: isCurrent
                                    text: "TOCANDO AGORA"
                                    color: Theme.brand
                                    font.pixelSize: 9; font.bold: true
                                }
                            }
                            Text { text: "#" + number; color: Theme.subtext; font.pixelSize: 11 }
                        }
                        MouseArea {
                            id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: player.playById(channelId)
                            onDoubleClicked: { player.playById(channelId); root.toggleFullscreen() }
                        }
                    }
                }

                // Rodapé status
                Rectangle {
                    Layout.fillWidth: true; height: 30; color: Theme.panel
                    Text { anchors.verticalCenter: parent.verticalCenter; x: 12
                        text: channels.loading ? channels.status : (root.activeModel().count + " canais")
                        color: Theme.subtext; font.pixelSize: 11 }
                }
            }
        }

        // ============ PLAYER ============
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; color: "black"

            MpvPlayer {
                id: mpv
                anchors.fill: parent
                // A janela nativa de vídeo só aparece DEPOIS que o mpv reportou
                // fileLoaded (primeiro frame chegou). Antes, "Selecione um
                // canal" e "Carregando..." da QML permanecem visíveis por baixo.
                visible: mpv.playing
                Component.onCompleted: player.attach(mpv)
                // Forward de eventos da janela nativa Win32: WM_MOUSEMOVE
                // reverte o auto-hide da sidebar, e duplo-clique toggle fullscreen
                // (eventos do HWND filho nunca chegam ao Qt sem isso).
                onUserActivity: root.showUI()
                onVideoDoubleClicked: root.toggleFullscreen()
            }

            // Botões topo-direito (escondem junto com a sidebar)
            RowLayout {
                id: topButtons
                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 12; spacing: 8; z: 30
                opacity: root.uiHidden ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 250 } }
                Button {
                    text: "Diagnóstico"
                    onClicked: app.navigate("diagnostic")
                    contentItem: Text { text: parent.text; color: Theme.text; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter }
                    background: Rectangle { radius: 8; color: "#1f2940cc"; border.color: Theme.border }
                    leftPadding: 12; rightPadding: 12; topPadding: 7; bottomPadding: 7
                }
                Button {
                    text: "Sair"
                    onClicked: {
                        // Pede pro mpv abortar streams antes da QML destruir
                        // a MpvPlayer — reduz drasticamente a trava de 1-2s.
                        mpv.command(["stop"])
                        auth.logout()
                        app.navigate("login")
                    }
                    contentItem: Text { text: parent.text; color: Theme.bad; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter }
                    background: Rectangle { radius: 8; color: "#1f2940cc"; border.color: Theme.border }
                    leftPadding: 12; rightPadding: 12; topPadding: 7; bottomPadding: 7
                }
            }

            // Mensagem central no player:
            //   - sem canal selecionado: "Selecione um canal"
            //   - com canal selecionado, mas mpv em buffering: "Carregando…"
            //   - reproduzindo: nada (vídeo cobre)
            // Antes o "Carregando…" aparecia eternamente no boot porque
            // mpv-core-idle=true (sem arquivo) era tratado como buffering.
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
            // Estado de erro: stream esgotou os retries (HTTP 406/404/etc).
            // Mostra mensagem clara em vez de "Carregando..." infinito.
            Column {
                anchors.centerIn: parent
                visible: player.hasError
                spacing: 8
                Text { anchors.horizontalCenter: parent.horizontalCenter
                    text: "⚠"; color: "#ffb86b"; font.pixelSize: 36 }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                    text: "Canal indisponível"; color: "white"; font.pixelSize: 18; font.bold: true }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                    text: "O servidor recusou a conexão. Tente outro canal."
                    color: "#a0a8b8"; font.pixelSize: 13 }
            }

            // Captura movimento do mouse para reexibir o overlay
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton
                onPositionChanged: overlay.flash()
                onDoubleClicked: root.toggleFullscreen()
                onClicked: root.forceActiveFocus()
            }

            // Overlay de informações (fade em 3s)
            Rectangle {
                id: overlay
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 110; opacity: 0
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: "#cc000000" }
                }
                Behavior on opacity { NumberAnimation { duration: 300 } }
                Timer { id: fadeTimer; interval: 3000; onTriggered: overlay.opacity = 0 }
                function flash() { opacity = 1; fadeTimer.restart() }

                ColumnLayout {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 16; spacing: 6
                    Text { text: player.currentName ? player.currentName : "Selecione um canal"
                        color: "white"; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { visible: epgTitle !== ""; text: epgTimes + "   " + epgTitle
                        color: "#d0d6e6"; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                    // Barra de progresso do programa atual
                    Rectangle {
                        visible: epgTitle !== ""
                        Layout.fillWidth: true; height: 4; radius: 2; color: "#40ffffff"
                        Rectangle { width: parent.width * epgProgress; height: parent.height; radius: 2; color: Theme.brand }
                    }
                    // Controles
                    RowLayout {
                        Layout.fillWidth: true; spacing: 14; Layout.topMargin: 4
                        Button {
                            text: mpv.paused ? "▶" : "⏸"
                            onClicked: mpv.togglePause()
                            contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { radius: 8; color: "#33ffffff" }
                            implicitWidth: 42; implicitHeight: 34
                        }
                        Text { text: "🔊"; color: "white"; font.pixelSize: 16 }
                        Slider {
                            id: vol; from: 0; to: 100; value: mpv.volume
                            Layout.preferredWidth: 140
                            onMoved: mpv.setVolume(value)
                            background: Rectangle { x: vol.leftPadding; y: vol.topPadding + vol.availableHeight/2 - 2
                                width: vol.availableWidth; height: 4; radius: 2; color: "#40ffffff"
                                Rectangle { width: vol.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.brand } }
                            handle: Rectangle { x: vol.leftPadding + vol.visualPosition*(vol.availableWidth-14)
                                y: vol.topPadding + vol.availableHeight/2 - 7; width: 14; height: 14; radius: 7; color: "white" }
                        }
                        Text { text: Math.round(mpv.volume) + "%"; color: "#d0d6e6"; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "⛶ Tela cheia"
                            onClicked: root.toggleFullscreen()
                            contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { radius: 8; color: "#33ffffff" }
                            leftPadding: 12; rightPadding: 12; topPadding: 7; bottomPadding: 7
                        }
                    }
                }
            }

            // Entrada numérica de canal
            Rectangle {
                id: numberEntry; visible: false
                anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 16
                width: 90; height: 56; radius: 10; color: "#cc000000"; z: 40
                Text { anchors.centerIn: parent; text: numberBuffer; color: "white"; font.pixelSize: 26; font.bold: true }
            }
        }
    }
}
