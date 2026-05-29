import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Player de VOD em tela cheia (cobre a tela hospedeira quando ativo).
// IMPORTANTE: o vídeo do mpv é uma janela Win32 nativa OPACA — QML por cima
// dele fica escondido. Por isso o chrome (voltar/título em cima, barra de
// controles embaixo) fica FORA do retângulo do vídeo. Em tela cheia (F11/
// duplo-clique) o vídeo ocupa tudo e o chrome some (ESC sai).
Item {
    id: overlay
    anchors.fill: parent
    visible: active
    z: 100

    property bool active: false
    property string infoText: ""
    property bool osFull: false      // tela cheia (sem chrome)
    signal nextRequested()
    signal prevRequested()

    function play(id) {
        overlay.active = true
        player.playById(id)
    }
    function stop() {
        vodMpv.command(["stop"])
        overlay.active = false
        if (overlay.osFull) toggleFull()
    }
    function toggleFull() {
        var w = Window.window
        if (!w) return
        overlay.osFull = !overlay.osFull
        w.visibility = overlay.osFull ? Window.FullScreen : Window.Windowed
    }
    function fmt(s) {
        if (!s || s <= 0 || isNaN(s)) return "00:00"
        s = Math.floor(s)
        var h = Math.floor(s/3600), m = Math.floor((s%3600)/60), ss = s%60
        function p(n){ return (n<10?"0":"")+n }
        return (h>0 ? h+":" : "") + p(m) + ":" + p(ss)
    }

    Shortcut { sequence: "Esc"; enabled: overlay.active
        onActivated: overlay.osFull ? overlay.toggleFull() : overlay.stop() }
    Shortcut { sequence: "F11"; enabled: overlay.active; onActivated: overlay.toggleFull() }
    Shortcut { sequence: "Space"; enabled: overlay.active; onActivated: vodMpv.togglePause() }

    Rectangle { anchors.fill: parent; color: "black" }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ----- Topo: voltar + título -----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            visible: !overlay.osFull
            color: Theme.bg
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 16; spacing: 12
                Rectangle {
                    width: 42; height: 42; radius: 21
                    color: backMouse.containsMouse ? Theme.panel2 : "transparent"
                    Image { anchors.centerIn: parent
                        source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/back.svg"
                        sourceSize.width: 24; sourceSize.height: 24 }
                    MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: overlay.stop() }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { Layout.fillWidth: true
                        text: player.currentName ? player.currentName : ""
                        color: Theme.text; font.pixelSize: 17; font.bold: true; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; visible: overlay.infoText !== ""
                        text: overlay.infoText; color: Theme.subtext; font.pixelSize: 12; elide: Text.ElideRight }
                }
            }
        }

        // ----- Vídeo -----
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "black"
            MpvPlayer {
                id: vodMpv
                anchors.fill: parent
                visible: vodMpv.playing
                Component.onCompleted: player.attach(vodMpv)
                onVideoDoubleClicked: overlay.toggleFull()
            }
            Text {
                anchors.centerIn: parent
                visible: vodMpv.buffering && !player.hasError
                text: "Carregando..."; color: "white"; font.pixelSize: 16
            }
            Column {
                anchors.centerIn: parent; visible: player.hasError; spacing: 8
                Text { anchors.horizontalCenter: parent.horizontalCenter
                    text: "Conteúdo indisponível"; color: "white"; font.pixelSize: 18; font.bold: true }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                    text: "O servidor recusou a conexão. Tente outro título."
                    color: "#a0a8b8"; font.pixelSize: 13 }
            }
        }

        // ----- Barra de controles (embaixo, fora do vídeo) -----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            visible: !overlay.osFull
            color: Theme.bg

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 24; anchors.rightMargin: 24
                anchors.topMargin: 10; anchors.bottomMargin: 10
                spacing: 8

                // Progresso
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text { text: overlay.fmt(vodMpv.position); color: Theme.subtext
                        font.pixelSize: 12; Layout.preferredWidth: 54; horizontalAlignment: Text.AlignRight }
                    Slider {
                        id: seek
                        Layout.fillWidth: true
                        from: 0; to: Math.max(1, vodMpv.duration)
                        enabled: vodMpv.duration > 0
                        onPressedChanged: if (!pressed) vodMpv.command(["seek", value, "absolute"])
                        Binding on value { value: vodMpv.position; when: !seek.pressed }
                        background: Rectangle {
                            x: seek.leftPadding; y: seek.topPadding + seek.availableHeight/2 - height/2
                            width: seek.availableWidth; height: 5; radius: 3; color: Theme.panel2
                            Rectangle { width: seek.visualPosition*parent.width; height: parent.height
                                radius: 3
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Theme.grad1 }
                                    GradientStop { position: 1.0; color: Theme.grad2 } } }
                        }
                        handle: Rectangle {
                            x: seek.leftPadding + seek.visualPosition*(seek.availableWidth - width)
                            y: seek.topPadding + seek.availableHeight/2 - height/2
                            width: 16; height: 16; radius: 8; color: Theme.brand; visible: seek.enabled
                        }
                    }
                    Text { text: overlay.fmt(vodMpv.duration); color: Theme.subtext
                        font.pixelSize: 12; Layout.preferredWidth: 54 }
                }

                // Botões (bem espaçados)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    Item { Layout.fillWidth: true }
                    Ctl { icon: "prev.svg";    onClicked: overlay.prevRequested() }
                    Ctl { icon: "rewind.svg";  onClicked: vodMpv.command(["seek", -10, "relative"]) }
                    Ctl { icon: vodMpv.paused ? "play.svg" : "pause.svg"; big: true
                        onClicked: vodMpv.togglePause() }
                    Ctl { icon: "forward.svg"; onClicked: vodMpv.command(["seek", 10, "relative"]) }
                    Ctl { icon: "next.svg";    onClicked: overlay.nextRequested() }
                    Item { Layout.fillWidth: true }

                    Ctl { icon: "audio.svg"
                        onClicked: { vodMpv.command(["cycle","aid"]); Window.window.notify("Faixa de áudio alterada") } }
                    Ctl { icon: "subtitles.svg"
                        onClicked: { vodMpv.command(["cycle","sub"]); Window.window.notify("Legenda alterada") } }
                    Ctl { icon: "fullscreen.svg"; onClicked: overlay.toggleFull() }
                    Ctl { icon: "stop.svg";       onClicked: overlay.stop() }
                }
            }
        }
    }

    component Ctl: Rectangle {
        id: c
        property string icon: ""
        property bool big: false
        signal clicked()
        implicitWidth: big ? 58 : 46
        implicitHeight: big ? 58 : 46
        radius: width/2
        color: big ? (cm.containsMouse ? Theme.panel2 : Theme.panel)
                   : (cm.containsMouse ? Theme.panel2 : "transparent")
        border.color: big ? Theme.brand : "transparent"
        border.width: big ? 2 : 0
        Image {
            anchors.centerIn: parent
            source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/" + c.icon
            sourceSize.width: c.big ? 30 : 24; sourceSize.height: c.big ? 30 : 24; smooth: true
        }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor; onClicked: c.clicked() }
    }
}
