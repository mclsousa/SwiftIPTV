import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Window
import SwiftIPTV

ApplicationWindow {
    id: win
    visible: true
    width: app.winW
    height: app.winH
    x: app.winX
    y: app.winY
    minimumWidth: 960
    minimumHeight: 600
    title: "SwiftIPTV"
    color: Theme.bg

    onClosing: app.saveWindow(win.x, win.y, win.width, win.height)

    // --- Fundo cinematográfico: gradiente escuro + "aurora" animada ---
    Rectangle {
        anchors.fill: parent
        z: -10
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.bg }
            GradientStop { position: 1.0; color: Theme.bg2 }
        }
    }
    // Aurora: blobs de luz suaves ESTÁTICOS atrás do conteúdo.
    // (Sem animação de propósito: animar continuamente mantinha a GPU ocupada
    //  o tempo todo — em GPUs fracas isso travava o vídeo ao abrir o canal,
    //  causando tela branca/“Carregando”. Estático = Qt fica ocioso, GPU livre.)
    Item {
        anchors.fill: parent
        z: -9
        clip: true
        Image {
            source: "qrc:/qt/qml/SwiftIPTV/resources/bg/blob-violet.svg"
            sourceSize.width: 900; sourceSize.height: 900
            width: 900; height: 900; opacity: 0.38
            x: -160; y: -200
        }
        Image {
            source: "qrc:/qt/qml/SwiftIPTV/resources/bg/blob-indigo.svg"
            sourceSize.width: 1000; sourceSize.height: 1000
            width: 1000; height: 1000; opacity: 0.34
            x: parent.width - 640; y: parent.height - 620
        }
        Image {
            source: "qrc:/qt/qml/SwiftIPTV/resources/bg/blob-magenta.svg"
            sourceSize.width: 720; sourceSize.height: 720
            width: 720; height: 720; opacity: 0.20
            x: parent.width * 0.42; y: parent.height * 0.20
        }
    }

    Loader {
        id: pageLoader
        anchors.fill: parent
        source: {
            switch (app.screen) {
            case "login":      return "LoginScreen.qml"
            case "dns":        return "DnsSetup.qml"
            case "home":       return "HomeScreen.qml"
            case "player":     return "LiveTV.qml"
            case "movies":     return "MoviesScreen.qml"
            case "series":     return "SeriesScreen.qml"
            case "settings":   return "SettingsScreen.qml"
            case "diagnostic": return "DiagnosticView.qml"
            }
            return "LoginScreen.qml"
        }
    }

    // Toast acessível de qualquer tela via Window.window.notify(...)
    Rectangle {
        id: toast
        property string msg: ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        radius: 10
        color: Theme.panel2
        border.color: Theme.border
        opacity: 0
        width: label.implicitWidth + 36
        height: 44
        z: 1000
        Text { id: label; anchors.centerIn: parent; text: toast.msg; color: Theme.text; font.pixelSize: 14 }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Timer { id: toastTimer; interval: 2600; onTriggered: toast.opacity = 0 }
    }

    function notify(m) { toast.msg = m; toast.opacity = 1; toastTimer.restart() }

    // --- Overlay de "Recarregando lista" (animação enquanto channels.loading) ---
    Rectangle {
        id: loadingOverlay
        anchors.fill: parent
        z: 2000
        visible: channels.loading
        color: "#cc000000"
        // Bloqueia interação com a UI por baixo durante o carregamento.
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Column {
            anchors.centerIn: parent
            spacing: 18

            Item {
                id: spinner
                width: 58; height: 58
                anchors.horizontalCenter: parent.horizontalCenter
                Canvas {
                    id: spinCanvas
                    anchors.fill: parent
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        var cx = width/2, cy = height/2, r = width/2 - 5
                        ctx.lineWidth = 5; ctx.lineCap = "round"
                        ctx.beginPath(); ctx.strokeStyle = Theme.panel2
                        ctx.arc(cx, cy, r, 0, 2*Math.PI); ctx.stroke()
                        ctx.beginPath(); ctx.strokeStyle = Theme.brand
                        ctx.arc(cx, cy, r, -Math.PI/2, Math.PI); ctx.stroke()
                    }
                }
                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 850
                    loops: Animation.Infinite; running: loadingOverlay.visible
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Recarregando lista..."
                color: Theme.text; font.pixelSize: 17; font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: channels.status
                visible: text !== ""
                color: Theme.subtext; font.pixelSize: 13
            }
        }
    }
}
