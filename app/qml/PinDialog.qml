import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Modal de PIN do Controle Parental: pede o PIN para abrir uma categoria
// bloqueada. Inclui recuperação ("Esqueci o PIN") confirmando a senha da conta.
// Use: pinDialog.openFor("NOME DA CATEGORIA"); trate onUnlocked.
Item {
    id: dlg
    anchors.fill: parent
    visible: false
    z: 200

    property string category: ""
    property string mode: "pin"     // "pin" | "recover"
    signal unlocked()

    function openFor(cat) {
        dlg.category = cat
        dlg.mode = "pin"
        pinField.text = ""; recPwd.text = ""
        errTxt.text = ""; recErr.text = ""
        dlg.visible = true
        pinField.forceActiveFocus()
    }
    function close() { dlg.visible = false }

    function tryPin() {
        if (channels.checkPin(pinField.text)) {
            channels.unlockSession(dlg.category)
            dlg.unlocked()
            dlg.close()
        } else {
            errTxt.text = "PIN incorreto."
            pinField.text = ""
        }
    }
    function tryRecover() {
        var saved = auth.rememberedPassword()
        if (saved === "") {
            recErr.text = "Senha não disponível. Faça login marcando \"Lembrar senha\" para poder recuperar."
        } else if (recPwd.text === saved) {
            channels.resetPin()
            Window.window.notify("PIN redefinido. Configure um novo em Configurações.")
            dlg.unlocked()
            dlg.close()
        } else {
            recErr.text = "Senha da conta incorreta."
        }
    }

    Rectangle {
        anchors.fill: parent; color: "#cc000000"
        MouseArea { anchors.fill: parent; onClicked: dlg.close() }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 400
        implicitHeight: colp.implicitHeight + 44
        radius: 14; color: Theme.panel; border.color: Theme.border
        MouseArea { anchors.fill: parent }   // clique dentro não fecha

        ColumnLayout {
            id: colp
            anchors.fill: parent; anchors.margins: 22; spacing: 14

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Image { source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/lock.svg"
                    sourceSize.width: 22; sourceSize.height: 22 }
                Text { Layout.fillWidth: true
                    text: dlg.mode === "pin" ? "Categoria bloqueada" : "Recuperar PIN"
                    color: Theme.text; font.pixelSize: 17; font.bold: true }
            }

            // ---- Modo PIN ----
            ColumnLayout {
                visible: dlg.mode === "pin"
                Layout.fillWidth: true; spacing: 12
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: "Digite o PIN para acessar \"" + dlg.category + "\"."
                    color: Theme.subtext; font.pixelSize: 14 }
                TextField {
                    id: pinField
                    Layout.preferredWidth: 150
                    echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; maximumLength: 4
                    color: Theme.text; font.pixelSize: 20; horizontalAlignment: TextInput.AlignHCenter
                    background: Rectangle { radius: 10; color: Theme.panel2; border.color: Theme.border }
                    topPadding: 12; bottomPadding: 12
                    onAccepted: dlg.tryPin()
                }
                Text { id: errTxt; text: ""; visible: text !== ""; color: Theme.bad; font.pixelSize: 13 }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    AppButton { kind: "primary"; text: "Desbloquear"; fontSize: 13; onClicked: dlg.tryPin() }
                    AppButton { kind: "ghost"; text: "Esqueci o PIN"; fontSize: 13
                        onClicked: { dlg.mode = "recover"; recErr.text = "" } }
                    Item { Layout.fillWidth: true }
                }
            }

            // ---- Modo recuperação ----
            ColumnLayout {
                visible: dlg.mode === "recover"
                Layout.fillWidth: true; spacing: 12
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: "Digite a senha da sua conta SwiftIPTV para redefinir o PIN."
                    color: Theme.subtext; font.pixelSize: 14 }
                TextField {
                    id: recPwd
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "Senha da conta"; placeholderTextColor: Theme.subtext
                    color: Theme.text
                    background: Rectangle { radius: 10; color: Theme.panel2; border.color: Theme.border }
                    leftPadding: 14; topPadding: 12; bottomPadding: 12
                    onAccepted: dlg.tryRecover()
                }
                Text { id: recErr; text: ""; visible: text !== ""; color: Theme.bad
                    font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    AppButton { kind: "primary"; text: "Redefinir PIN"; fontSize: 13; onClicked: dlg.tryRecover() }
                    AppButton { kind: "ghost"; text: "Voltar"; fontSize: 13; onClicked: dlg.mode = "pin" }
                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
