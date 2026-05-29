import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Coluna de player de VOD (Filmes/Séries) com barra de controles completa.
// Usada como a 3ª coluna das telas split de Filmes e Séries. Reaproveita o
// StreamPlayer global (attach no Component.onCompleted do MpvPlayer).
//
// O pai toca um título chamando player.playById(id); a navegação anterior/
// próximo é feita pelo pai (que conhece a lista) via os sinais abaixo.
Item {
    id: root

    property string infoText: ""        // ex.: "Temporada 1 • Episódio 3"
    property bool   fullscreen: false
    signal nextRequested()
    signal prevRequested()
    signal fullscreenRequested()

    // Exposto pro pai parar o vídeo ao sair da tela.
    function stop() { vodMpv.command(["stop"]) }

    function fmt(s) {
        if (!s || s <= 0 || isNaN(s)) return "00:00"
        s = Math.floor(s)
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), ss = s % 60
        function p(n) { return (n < 10 ? "0" : "") + n }
        return (h > 0 ? h + ":" : "") + p(m) + ":" + p(ss)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.fullscreen ? 0 : 16
        spacing: 12

        // ---------- Vídeo ----------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "black"
            radius: root.fullscreen ? 0 : 8
            clip: true

            MpvPlayer {
                id: vodMpv
                anchors.fill: parent
                visible: vodMpv.playing
                Component.onCompleted: player.attach(vodMpv)
                onVideoDoubleClicked: root.fullscreenRequested()
            }
            Text {
                anchors.centerIn: parent
                visible: !player.currentId || player.currentId === ""
                text: "Selecione um título"; color: "#a0a8b8"; font.pixelSize: 18
            }
            Text {
                anchors.centerIn: parent
                visible: vodMpv.buffering && player.currentId && player.currentId !== "" && !player.hasError
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
            MouseArea {
                anchors.fill: parent; acceptedButtons: Qt.LeftButton
                onDoubleClicked: root.fullscreenRequested()
            }
        }

        // ---------- Título + info ----------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: player.currentName ? player.currentName : ""
                color: Theme.text; font.pixelSize: 20; font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: root.infoText !== ""
                text: root.infoText
                color: Theme.subtext; font.pixelSize: 13
                elide: Text.ElideRight
            }
        }

        // ---------- Barra de progresso ----------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: root.fmt(vodMpv.position)
                color: Theme.subtext; font.pixelSize: 12
                Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight
            }
            Slider {
                id: seek
                Layout.fillWidth: true
                from: 0; to: Math.max(1, vodMpv.duration)
                enabled: vodMpv.duration > 0
                onPressedChanged: if (!pressed) vodMpv.command(["seek", value, "absolute"])
                Binding on value { value: vodMpv.position; when: !seek.pressed }

                background: Rectangle {
                    x: seek.leftPadding; y: seek.topPadding + seek.availableHeight / 2 - height / 2
                    width: seek.availableWidth; height: 5; radius: 3
                    color: Theme.panel2
                    Rectangle {
                        width: seek.visualPosition * parent.width; height: parent.height
                        color: Theme.brand; radius: 3
                    }
                }
                handle: Rectangle {
                    x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
                    y: seek.topPadding + seek.availableHeight / 2 - height / 2
                    width: 14; height: 14; radius: 7
                    color: Theme.brand
                    visible: seek.enabled
                }
            }
            Text {
                text: root.fmt(vodMpv.duration)
                color: Theme.subtext; font.pixelSize: 12
                Layout.preferredWidth: 52
            }
        }

        // ---------- Botões de controle ----------
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: 6

            CtlBtn { icon: "back.svg";    tip: "Voltar"
                onClicked: root.fullscreen ? root.fullscreenRequested() : app.navigate("home") }
            Item { Layout.fillWidth: true }

            CtlBtn { icon: "prev.svg";    tip: "Anterior";   onClicked: root.prevRequested() }
            CtlBtn { icon: "rewind.svg";  tip: "-10s";       onClicked: vodMpv.command(["seek", -10, "relative"]) }
            CtlBtn {
                icon: vodMpv.paused ? "play.svg" : "pause.svg"
                big: true; tip: vodMpv.paused ? "Reproduzir" : "Pausar"
                enabled: player.currentId !== ""
                onClicked: vodMpv.togglePause()
            }
            CtlBtn { icon: "forward.svg"; tip: "+10s";       onClicked: vodMpv.command(["seek", 10, "relative"]) }
            CtlBtn { icon: "next.svg";    tip: "Próximo";    onClicked: root.nextRequested() }

            Item { Layout.fillWidth: true }
            CtlBtn { icon: "stop.svg";       tip: "Parar"
                onClicked: { vodMpv.command(["stop"]) } }
            CtlBtn { icon: "audio.svg";      tip: "Faixa de áudio"
                onClicked: { vodMpv.command(["cycle", "aid"]); Window.window.notify("Faixa de áudio alterada") } }
            CtlBtn { icon: "subtitles.svg";  tip: "Legenda"
                onClicked: { vodMpv.command(["cycle", "sub"]); Window.window.notify("Legenda alterada") } }
            CtlBtn { icon: "fullscreen.svg"; tip: "Tela cheia"
                onClicked: root.fullscreenRequested() }
        }
    }

    // Botão de controle (ícone branco em fundo arredondado)
    component CtlBtn: Rectangle {
        id: cb
        property string icon: ""
        property string tip: ""
        property bool big: false
        // 'enabled' é o herdado de Item (não redeclarar). Default já é true.
        signal clicked()
        implicitWidth: big ? 56 : 44
        implicitHeight: big ? 56 : 44
        radius: width / 2
        color: cb.big ? (cbMouse.containsMouse ? Theme.panel2 : Theme.panel)
                      : (cbMouse.containsMouse ? Theme.panel2 : "transparent")
        border.color: cb.big ? Theme.brand : "transparent"
        border.width: cb.big ? 2 : 0
        opacity: cb.enabled ? 1 : 0.4
        Image {
            anchors.centerIn: parent
            source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/" + cb.icon
            sourceSize.width: cb.big ? 30 : 24
            sourceSize.height: cb.big ? 30 : 24
            smooth: true
        }
        MouseArea {
            id: cbMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: cb.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (cb.enabled) cb.clicked()
        }
    }
}
