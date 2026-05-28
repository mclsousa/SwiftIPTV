import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SwiftIPTV

Item {
    anchors.fill: parent

    // Fundo: o pattern hexagonal global (Main.qml) já está atrás; aqui só
    // cobrimos com a cor base. Sem gradiente — o modelo TV DIG+ é preto puro.
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: 0.92   // deixa o hexágono "respirar" sutilmente
    }

    Connections {
        target: auth
        function onLoginFailed(message) { errorLabel.text = message }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 380
        spacing: 22

        // Logo TV DIG+ centralizada (arquivo fornecido pelo usuário).
        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/qt/qml/SwiftIPTV/resources/logos/logo-tvdig.png"
            sourceSize.width: 260
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Entre com sua conta"
            color: Theme.subtext
            font.pixelSize: 14
            Layout.topMargin: -10
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
                color: Theme.panel
                border.color: userField.activeFocus ? Theme.brand : Theme.border
                border.width: userField.activeFocus ? 1 : 1
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
                color: Theme.panel
                border.color: passField.activeFocus ? Theme.brand : Theme.border
                border.width: 1
            }
            leftPadding: 16; topPadding: 14; bottomPadding: 14
            onAccepted: loginBtn.clicked()
        }

        RowLayout {
            Layout.fillWidth: true
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
                    color: remember.checked ? Theme.brand : Theme.panel
                    border.color: remember.checked ? Theme.brand : Theme.border
                    // V de check em SVG path (sem emoji)
                    Canvas {
                        anchors.fill: parent
                        visible: remember.checked
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = "#0a0a0a"
                            ctx.lineWidth = 2.4
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.moveTo(width*0.22, height*0.52)
                            ctx.lineTo(width*0.44, height*0.72)
                            ctx.lineTo(width*0.80, height*0.32)
                            ctx.stroke()
                        }
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

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
                color: loginBtn.down ? Theme.brand2 : Theme.brand
                opacity: loginBtn.enabled ? 1 : 0.55
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

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Testar minha conexão"
            color: Theme.brand
            font.pixelSize: 13
            font.underline: true
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: login.openDiagnostics() }
        }
    }
}
