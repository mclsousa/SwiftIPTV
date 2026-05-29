import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SwiftIPTV

// Tela de login — visual cinematográfico (estilo HBO Max): fundo escuro com
// brilho roxo sutil atrás de um card central de vidro.
Item {
    anchors.fill: parent

    Connections {
        target: auth
        function onLoginFailed(message) { errorLabel.text = message }
    }

    // Brilho roxo radial atrás do card (cinematográfico)
    Rectangle {
        anchors.centerIn: card
        width: 720; height: 720; radius: 360
        opacity: 0.22
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.brand }
            GradientStop { position: 0.55; color: "#00000000" }
        }
    }

    // Card central
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 420
        radius: 18
        color: Qt.rgba(0.09, 0.075, 0.12, 0.92)   // painel translúcido
        border.color: Theme.border
        border.width: 1
        implicitHeight: form.implicitHeight + 64

        ColumnLayout {
            id: form
            anchors.fill: parent
            anchors.margins: 32
            spacing: 20

            Logo {
                Layout.alignment: Qt.AlignHCenter
                markSize: 58
                fontSize: 30
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -8
                text: "Entre com sua conta"
                color: Theme.subtext
                font.pixelSize: 14
            }

            TextField {
                id: userField
                Layout.fillWidth: true
                placeholderText: "Usuário"
                text: login.savedUsername
                color: Theme.text
                placeholderTextColor: Theme.subtext
                font.pixelSize: 14
                background: Rectangle {
                    radius: 12
                    color: Theme.panel2
                    border.color: userField.activeFocus ? Theme.brand : Theme.border
                    border.width: 1
                }
                leftPadding: 16; topPadding: 14; bottomPadding: 14
            }
            TextField {
                id: passField
                Layout.fillWidth: true
                placeholderText: "Senha"
                echoMode: TextInput.Password
                text: login.savedPassword
                color: Theme.text
                placeholderTextColor: Theme.subtext
                font.pixelSize: 14
                background: Rectangle {
                    radius: 12
                    color: Theme.panel2
                    border.color: passField.activeFocus ? Theme.brand : Theme.border
                    border.width: 1
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
                        anchors.fill: parent
                        visible: remember.checked
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = "#ffffff"
                            ctx.lineWidth = 2.4
                            ctx.lineCap = "round"; ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.moveTo(width*0.22, height*0.52)
                            ctx.lineTo(width*0.44, height*0.72)
                            ctx.lineTo(width*0.80, height*0.32)
                            ctx.stroke()
                        }
                    }
                }
            }

            // Botão Entrar (gradiente roxo -> índigo)
            Button {
                id: loginBtn
                Layout.fillWidth: true
                enabled: !auth.busy
                text: auth.busy ? "Entrando..." : "Entrar"
                onClicked: { errorLabel.text = ""; login.submit(userField.text, passField.text, remember.checked) }
                contentItem: Text {
                    text: loginBtn.text
                    color: Theme.buttonText
                    font.pixelSize: 15; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    radius: 12
                    opacity: loginBtn.enabled ? 1 : 0.55
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: loginBtn.down ? Theme.grad2 : Theme.grad1 }
                        GradientStop { position: 1.0; color: loginBtn.down ? Theme.grad1 : Theme.grad2 }
                    }
                }
                topPadding: 14; bottomPadding: 14
            }

            Text {
                id: errorLabel
                Layout.fillWidth: true
                text: ""
                visible: text.length > 0
                color: Theme.bad; font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
