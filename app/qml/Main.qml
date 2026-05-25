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

    Loader {
        id: pageLoader
        anchors.fill: parent
        source: {
            switch (app.screen) {
            case "login":      return "LoginScreen.qml"
            case "dns":        return "DnsSetup.qml"
            case "player":     return "MainPlayer.qml"
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
        color: "#1f2940"
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
}
