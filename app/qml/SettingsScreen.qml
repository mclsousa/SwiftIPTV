import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Tela de Configurações do TV DIG+ (Fase 4 do redesign).
// Layout do modelo: título centralizado + voltar, grade de "pílulas"
// (ícone + texto), e Endereço MAC / conta no rodapé.
Item {
    id: root
    anchors.fill: parent
    opacity: 0
    NumberAnimation on opacity { from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic }

    // MAC do dispositivo (calculado uma vez ao abrir a tela).
    readonly property string mac: app.macAddress()

    // Controle parental
    property bool parentalOpen: false
    property bool parentalAuthed: false
    property bool parentalRecover: false
    property var  parentalCats: []
    function openParental() {
        root.parentalAuthed = !channels.parentalHasPin
        root.parentalRecover = false
        root.parentalCats = channels.allCategories()
        root.parentalOpen = true
    }
    function refreshParentalCats() { root.parentalCats = channels.allCategories() }

    // Leve escurecida sobre a aurora (mantém legibilidade sem esconder o fundo)
    Rectangle { anchors.fill: parent; color: Theme.bg; opacity: 0.45 }

    // ───────── Cabeçalho: voltar + título ─────────
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 22
        height: 48

        // Botão voltar (para a Home)
        Rectangle {
            id: backBtn
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 44; radius: 22
            color: backMouse.containsMouse ? Theme.panel2 : "transparent"
            Image {
                anchors.centerIn: parent
                source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/back.svg"
                sourceSize.width: 26; sourceSize.height: 26; smooth: true
            }
            MouseArea {
                id: backMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: app.navigate("home")
            }
        }

        Text {
            anchors.centerIn: parent
            text: "Configurações"
            color: Theme.text
            font.pixelSize: 26; font.bold: true
        }
    }

    // ───────── Grade de opções ─────────
    GridLayout {
        anchors.centerIn: parent
        columns: 3
        rowSpacing: 18
        columnSpacing: 18

        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/dns.svg"
            label: "Otimizar Minha Conexão"
            sub: "Trocar o DNS do PC"
            onClicked: app.navigate("dns")
        }
        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/pulse.svg"
            label: "Testar Minha Conexão"
            sub: "Latência, velocidade, servidores"
            onClicked: app.navigate("diagnostic")
        }
        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/refresh.svg"
            label: "Recarregar Lista"
            sub: "Buscar canais atualizados"
            onClicked: { channels.loadList(true); Window.window.notify("Recarregando lista...") }
        }
        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/trash.svg"
            label: "Limpar Cache"
            sub: "Apagar a lista salva em disco"
            onClicked: {
                var n = channels.clearCache()
                Window.window.notify(n + " arquivo(s) de cache removido(s)")
            }
        }
        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/lock.svg"
            label: "Controle Parental"
            sub: channels.parentalHasPin ? "Ativo — categorias protegidas" : "Proteger categorias adultas/específicas"
            onClicked: root.openParental()
        }
        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/info.svg"
            label: "Sobre o App"
            sub: "SwiftIPTV v" + app.appVersion
            onClicked: Window.window.notify("SwiftIPTV v" + app.appVersion)
        }
        OptionButton {
            iconSource: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/logout.svg"
            label: "Sair da Conta"
            sub: "Encerrar a sessão"
            labelColor: Theme.bad
            onClicked: { auth.logout(); app.navigate("login") }
        }
    }

    // ───────── Rodapé: conta + MAC + versão ─────────
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        spacing: 4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
                var u = auth.usernameIptv ? auth.usernameIptv : auth.username
                var parts = []
                if (u) parts.push("Usuário: " + u)
                if (auth.expiresAt) parts.push("Vence: " + auth.expiresAt)
                return parts.join("    •    ")
            }
            color: Theme.subtext; font.pixelSize: 13; font.bold: true
            visible: text !== ""
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Endereço MAC: " + (root.mac ? root.mac : "—") + "    •    SwiftIPTV v" + app.appVersion
            color: Theme.subtext; font.pixelSize: 12
        }
    }

    // ─────────────────────────────────────────────
    // Overlay: Controle Parental
    // ─────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.parentalOpen
        z: 50
        color: "#cc000000"
        MouseArea { anchors.fill: parent }   // bloqueia interação por baixo

        Rectangle {
            anchors.centerIn: parent
            width: 560
            height: Math.min(parent.height - 70, 680)
            radius: 16; color: Theme.panel; border.color: Theme.border

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 22; spacing: 14

                // Cabeçalho
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Image { source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/lock.svg"
                        sourceSize.width: 22; sourceSize.height: 22 }
                    Text { Layout.fillWidth: true; text: "Controle Parental"
                        color: Theme.text; font.pixelSize: 19; font.bold: true }
                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: xMouse.containsMouse ? Theme.panel2 : "transparent"
                        Text { anchors.centerIn: parent; text: "×"; color: Theme.text; font.pixelSize: 22 }
                        MouseArea { id: xMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.parentalOpen = false }
                    }
                }

                // ===== Entrada de PIN (há PIN e ainda não autenticou) =====
                ColumnLayout {
                    visible: !root.parentalAuthed
                    Layout.fillWidth: true; spacing: 12
                    Text { text: "Digite o PIN para gerenciar as proteções."
                        color: Theme.subtext; font.pixelSize: 14 }
                    TextField {
                        id: unlockPin
                        Layout.preferredWidth: 160
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhDigitsOnly
                        maximumLength: 4
                        color: Theme.text; font.pixelSize: 18
                        horizontalAlignment: TextInput.AlignHCenter
                        background: Rectangle { radius: 10; color: Theme.panel2; border.color: Theme.border }
                        topPadding: 12; bottomPadding: 12
                    }
                    Text { id: unlockErr; text: ""; visible: text !== ""; color: Theme.bad; font.pixelSize: 13 }
                    RowLayout {
                        spacing: 10
                        AppButton {
                            kind: "primary"; text: "Entrar"; fontSize: 13
                            onClicked: {
                                if (channels.checkPin(unlockPin.text)) { root.parentalAuthed = true; unlockErr.text = ""; unlockPin.text = "" }
                                else unlockErr.text = "PIN incorreto."
                            }
                        }
                        AppButton {
                            kind: "ghost"; text: "Esqueci o PIN"; fontSize: 13
                            onClicked: { root.parentalRecover = true; unlockErr.text = "" }
                        }
                    }
                    // Recuperação: confirma a senha da conta e redefine o PIN.
                    ColumnLayout {
                        visible: root.parentalRecover
                        Layout.fillWidth: true; spacing: 8
                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
                            text: "Digite a senha da sua conta SwiftIPTV para redefinir o PIN."
                            color: Theme.subtext; font.pixelSize: 13 }
                        TextField {
                            id: recAcc; Layout.preferredWidth: 240
                            echoMode: TextInput.Password
                            placeholderText: "Senha da conta"; placeholderTextColor: Theme.subtext
                            color: Theme.text
                            background: Rectangle { radius: 10; color: Theme.panel2; border.color: Theme.border }
                            leftPadding: 14; topPadding: 11; bottomPadding: 11
                        }
                        Text { id: recAccErr; text: ""; visible: text !== ""; color: Theme.bad
                            font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        AppButton {
                            kind: "primary"; text: "Redefinir PIN"; fontSize: 13
                            onClicked: {
                                var saved = auth.rememberedPassword()
                                if (saved === "") recAccErr.text = "Senha não disponível. Faça login marcando \"Lembrar senha\"."
                                else if (recAcc.text === saved) {
                                    channels.resetPin(); recAcc.text = ""; recAccErr.text = ""
                                    root.parentalRecover = false; root.parentalAuthed = true
                                    Window.window.notify("PIN redefinido. Defina um novo abaixo.")
                                } else recAccErr.text = "Senha da conta incorreta."
                            }
                        }
                    }
                }

                // ===== Gestão (autenticado ou sem PIN) =====
                ColumnLayout {
                    visible: root.parentalAuthed
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12

                    Text { text: channels.parentalHasPin ? "Trocar PIN" : "Definir PIN"
                        color: Theme.text; font.pixelSize: 15; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        TextField {
                            id: curPin; visible: channels.parentalHasPin
                            Layout.fillWidth: true
                            placeholderText: "PIN atual"; placeholderTextColor: Theme.subtext
                            echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; maximumLength: 4
                            color: Theme.text
                            background: Rectangle { radius: 10; color: Theme.panel2; border.color: Theme.border }
                            leftPadding: 14; topPadding: 11; bottomPadding: 11
                        }
                        TextField {
                            id: newPin; Layout.fillWidth: true
                            placeholderText: "Novo PIN (4 dígitos)"; placeholderTextColor: Theme.subtext
                            echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; maximumLength: 4
                            color: Theme.text
                            background: Rectangle { radius: 10; color: Theme.panel2; border.color: Theme.border }
                            leftPadding: 14; topPadding: 11; bottomPadding: 11
                        }
                        TextField {
                            id: confPin; Layout.fillWidth: true
                            placeholderText: "Confirmar"; placeholderTextColor: Theme.subtext
                            echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; maximumLength: 4
                            color: Theme.text
                            background: Rectangle { radius: 10; color: Theme.panel2; border.color: Theme.border }
                            leftPadding: 14; topPadding: 11; bottomPadding: 11
                        }
                    }
                    Text { id: pinMsg; text: ""; visible: text !== ""; font.pixelSize: 13 }
                    RowLayout {
                        spacing: 10
                        AppButton {
                            kind: "primary"; text: "Salvar PIN"; fontSize: 13
                            onClicked: {
                                if (newPin.text.length < 4) { pinMsg.color = Theme.bad; pinMsg.text = "O PIN deve ter 4 dígitos."; return }
                                if (newPin.text !== confPin.text) { pinMsg.color = Theme.bad; pinMsg.text = "Os PINs não conferem."; return }
                                if (channels.setPin(curPin.text, newPin.text)) {
                                    pinMsg.color = Theme.ok; pinMsg.text = "PIN salvo."
                                    curPin.text = ""; newPin.text = ""; confPin.text = ""
                                } else { pinMsg.color = Theme.bad; pinMsg.text = "PIN atual incorreto." }
                            }
                        }
                        AppButton {
                            kind: "secondary"; text: "Remover PIN"; fontSize: 13
                            visible: channels.parentalHasPin
                            onClicked: {
                                if (channels.clearPin(curPin.text)) { pinMsg.color = Theme.ok; pinMsg.text = "PIN removido."; curPin.text = "" }
                                else { pinMsg.color = Theme.bad; pinMsg.text = "Informe o PIN atual para remover." }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                    // Auto-adulto
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text { Layout.fillWidth: true; text: "Bloquear categorias adultas automaticamente"
                            color: Theme.text; font.pixelSize: 14; wrapMode: Text.WordWrap }
                        Rectangle {
                            width: 48; height: 26; radius: 13
                            color: channels.parentalAutoAdult ? Theme.brand : Theme.panel2
                            border.color: Theme.border
                            Rectangle {
                                width: 20; height: 20; radius: 10; color: "white"
                                anchors.verticalCenter: parent.verticalCenter
                                x: channels.parentalAutoAdult ? parent.width - 23 : 3
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { channels.setAutoAdult(!channels.parentalAutoAdult); root.refreshParentalCats() } }
                        }
                    }

                    AppButton {
                        kind: "secondary"; fontSize: 13
                        text: "Liberar conteúdo bloqueado nesta sessão"
                        onClicked: { channels.unlockAllSession(); Window.window.notify("Conteúdo liberado nesta sessão") }
                    }

                    Text { text: "Bloquear categorias específicas"; color: Theme.text
                        font.pixelSize: 15; font.bold: true }

                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; model: root.parentalCats; spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { }
                        delegate: Rectangle {
                            id: catDel
                            required property var modelData
                            width: ListView.view.width; height: 46; radius: 8; color: Theme.panel2
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0
                                    Text { Layout.fillWidth: true; text: catDel.modelData.name; color: Theme.text
                                        font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                                    Text { text: (catDel.modelData.type === "live" ? "Ao Vivo" : (catDel.modelData.type === "movie" ? "Filmes" : "Séries"))
                                           + (catDel.modelData.adult ? "  ·  adulto" : "")
                                        color: catDel.modelData.adult ? Theme.warn : Theme.subtext; font.pixelSize: 11 }
                                }
                                Rectangle {
                                    implicitWidth: lkTxt.implicitWidth + 24; height: 30; radius: 15
                                    color: catDel.modelData.locked ? Theme.brand : "transparent"
                                    border.color: catDel.modelData.locked ? Theme.brand : Theme.border
                                    Text { id: lkTxt; anchors.centerIn: parent
                                        text: catDel.modelData.locked ? "Bloqueada" : "Livre"
                                        color: catDel.modelData.locked ? Theme.buttonText : Theme.subtext
                                        font.pixelSize: 12; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { channels.toggleCategoryLock(catDel.modelData.name); root.refreshParentalCats() } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // Pílula de opção: ícone + título + subtítulo
    // ─────────────────────────────────────────────
    component OptionButton: Rectangle {
        id: opt
        property string iconSource: ""
        property string label: ""
        property string sub: ""
        property color  labelColor: Theme.text
        signal clicked()

        Layout.preferredWidth: 300
        Layout.preferredHeight: 76
        radius: 14
        color: hovered ? Theme.panel2 : Theme.panel
        border.color: hovered ? Theme.brand : Theme.border
        border.width: 1
        property bool hovered: false
        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18; anchors.rightMargin: 16
            spacing: 16
            Image {
                source: opt.iconSource
                sourceSize.width: 30; sourceSize.height: 30; smooth: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: opt.label
                    color: opt.labelColor
                    font.pixelSize: 16; font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: opt.sub !== ""
                    text: opt.sub
                    color: Theme.subtext
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onEntered: opt.hovered = true
            onExited:  opt.hovered = false
            onClicked: opt.clicked()
        }
    }
}
