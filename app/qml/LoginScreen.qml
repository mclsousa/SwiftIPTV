import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SwiftIPTV

Item {
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#141b30" }
            GradientStop { position: 1.0; color: "#0b0f1a" }
        }
    }

    Connections {
        target: auth
        function onLoginFailed(message) { errorLabel.text = message }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 360
        spacing: 18

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 64; height: 64; radius: 18; color: Theme.brand
            Text { anchors.centerIn: parent; text: "⚡"; font.pixelSize: 30; color: "white" }
        }
        Text { Layout.alignment: Qt.AlignHCenter; text: "SwiftIPTV"; color: Theme.text; font.pixelSize: 26; font.bold: true }
        Text { Layout.alignment: Qt.AlignHCenter; text: "Entre com sua conta"; color: Theme.subtext; font.pixelSize: 14 }

        TextField {
            id: userField
            Layout.fillWidth: true
            placeholderText: "Usuário"
            text: login.savedUsername
            color: Theme.text
            placeholderTextColor: Theme.subtext
            background: Rectangle { radius: 10; color: Theme.panel2; border.color: Theme.border }
            leftPadding: 14; topPadding: 12; bottomPadding: 12
        }
        TextField {
            id: passField
            Layout.fillWidth: true
            placeholderText: "Senha"
            echoMode: TextInput.Password
            text: login.savedPassword
            color: Theme.text
            placeholderTextColor: Theme.subtext
            background: Rectangle { radius: 10; color: Theme.panel2; border.color: Theme.border }
            leftPadding: 14; topPadding: 12; bottomPadding: 12
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
                    leftPadding: remember.indicator.width + 6; verticalAlignment: Text.AlignVCenter
                }
                indicator: Rectangle {
                    width: 18; height: 18; radius: 4; x: 0; y: parent.height/2 - 9
                    color: remember.checked ? Theme.brand : Theme.panel2
                    border.color: Theme.border
                    Text { anchors.centerIn: parent; text: "✓"; color: "white"; visible: remember.checked; font.pixelSize: 12 }
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
            contentItem: Text { text: loginBtn.text; color: "white"; font.pixelSize: 15; font.bold: true; horizontalAlignment: Text.AlignHCenter }
            background: Rectangle { radius: 10; color: loginBtn.down ? Theme.brand2 : Theme.brand; opacity: loginBtn.enabled ? 1 : 0.6 }
            topPadding: 13; bottomPadding: 13
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
            color: Theme.brand; font.pixelSize: 13; font.underline: true
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: login.openDiagnostics() }
        }
    }
}
