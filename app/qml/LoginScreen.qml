import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SwiftIPTV

// Login cinematográfico: card de vidro que surge com fade+escala, logo com
// brilho pulsante e botão com gradiente/realce. Fundo aurora vem do Main.qml.
Item {
    anchors.fill: parent

    Connections {
        target: auth
        function onLoginFailed(message) { errorLabel.text = message }
    }

    // Glow roxo atrás do card
    Rectangle {
        anchors.centerIn: card
        width: 760; height: 760; radius: 380
        opacity: 0.25
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.brand }
            GradientStop { position: 0.6; color: "#00000000" }
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 430
        radius: 20
        color: Qt.rgba(0.09, 0.075, 0.12, 0.82)
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
        implicitHeight: form.implicitHeight + 68

        // Entrada: fade + escala com leve overshoot
        opacity: 0
        scale: 0.94
        NumberAnimation on opacity { from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
        NumberAnimation on scale   { from: 0.94; to: 1; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.1 }

        ColumnLayout {
            id: form
            anchors.fill: parent
            anchors.margins: 34
            spacing: 20

            // Logo + glow pulsante
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: logo.implicitWidth
                implicitHeight: 76
                Rectangle {
                    anchors.centerIn: parent
                    width: 150; height: 150; radius: 75
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.brand }
                        GradientStop { position: 0.6; color: "#00000000" }
                    }
                    opacity: 0.35
                    SequentialAnimation on opacity { loops: Animation.Infinite
                        NumberAnimation { to: 0.55; duration: 1600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.30; duration: 1600; easing.type: Easing.InOutSine } }
                }
                Logo { id: logo; anchors.centerIn: parent; markSize: 60; fontSize: 30 }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -6
                text: "Entre com sua conta"
                color: Theme.subtext; font.pixelSize: 14
            }

            TextField {
                id: userField
                Layout.fillWidth: true
                placeholderText: "Usuário"
                text: login.savedUsername
                color: Theme.text; placeholderTextColor: Theme.subtext; font.pixelSize: 14
                background: Rectangle {
                    radius: 12; color: Theme.panel2
                    border.color: userField.activeFocus ? Theme.brand : Theme.border
                    border.width: userField.activeFocus ? 2 : 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
                leftPadding: 16; topPadding: 14; bottomPadding: 14
            }
            TextField {
                id: passField
                Layout.fillWidth: true
                placeholderText: "Senha"
                echoMode: TextInput.Password
                text: login.savedPassword
                color: Theme.text; placeholderTextColor: Theme.subtext; font.pixelSize: 14
                background: Rectangle {
                    radius: 12; color: Theme.panel2
                    border.color: passField.activeFocus ? Theme.brand : Theme.border
                    border.width: passField.activeFocus ? 2 : 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
                leftPadding: 16; topPadding: 14; bottomPadding: 14
                onAccepted: loginBtn.clicked()
            }

            CheckBox {
                id: remember
                checked: login.rememberByDefault
                text: "Lembrar minha senha"
                contentItem: Text {
                    text: remember.text; color: Theme.subtext; font.pixelSize: 13
                    leftPadding: remember.indicator.width + 8; verticalAlignment: Text.AlignVCenter
                }
                indicator: Rectangle {
                    width: 18; height: 18; radius: 4; x: 0; y: parent.height/2 - 9
                    color: remember.checked ? Theme.brand : Theme.panel2
                    border.color: remember.checked ? Theme.brand : Theme.border
                    Canvas {
                        anchors.fill: parent; visible: remember.checked
                        onPaint: {
                            var ctx = getContext("2d"); ctx.reset()
                            ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 2.4
                            ctx.lineCap = "round"; ctx.lineJoin = "round"
                            ctx.beginPath(); ctx.moveTo(width*0.22, height*0.52)
                            ctx.lineTo(width*0.44, height*0.72); ctx.lineTo(width*0.80, height*0.32); ctx.stroke()
                        }
                    }
                }
            }

            Button {
                id: loginBtn
                Layout.fillWidth: true
                enabled: !auth.busy
                text: auth.busy ? "Entrando..." : "Entrar"
                onClicked: { errorLabel.text = ""; login.submit(userField.text, passField.text, remember.checked) }
                scale: down ? 0.98 : (hovered ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                contentItem: Text {
                    text: loginBtn.text; color: Theme.buttonText
                    font.pixelSize: 15; font.bold: true; horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    radius: 12
                    opacity: loginBtn.enabled ? 1 : 0.55
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: loginBtn.down ? Theme.grad2 : Theme.grad1 }
                        GradientStop { position: 1.0; color: loginBtn.down ? Theme.grad1 : Theme.grad2 }
                    }
                    // realce no hover
                    Rectangle {
                        anchors.fill: parent; radius: 12
                        color: "#ffffff"; opacity: loginBtn.hovered ? 0.10 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
                topPadding: 14; bottomPadding: 14
            }

            Text {
                id: errorLabel
                Layout.fillWidth: true
                text: ""; visible: text.length > 0
                color: Theme.bad; font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            }
        }
    }
}
