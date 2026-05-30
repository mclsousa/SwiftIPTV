import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SwiftIPTV

// Botão estilo Netflix/HBO (escolha do usuário):
//   kind "primary"   -> BRANCO sólido, texto/ícone escuros (ação principal)
//   kind "secondary" -> cinza escuro sólido, texto branco
//   kind "ghost"     -> transparente, realça no hover
// Cantos pequenos (quase retos). Ícone opcional à esquerda.
// NÃO redeclara 'enabled' (usa o herdado de Item).
Rectangle {
    id: btn
    property string text: ""
    property string iconSource: ""
    property string kind: "primary"
    property int fontSize: 14
    property int iconSize: 18
    property string tooltip: ""    // dica ao passar o mouse (útil em botões só-ícone)
    signal clicked()

    readonly property color fg: kind === "primary" ? Theme.btnPrimaryText : Theme.text

    implicitHeight: 46
    // Texto vazio => botão só-ícone (quadrado).
    implicitWidth: text === "" ? implicitHeight : row.implicitWidth + (kind === "ghost" ? 22 : 40)
    radius: 6                                  // cantos bem menores
    opacity: btn.enabled ? 1.0 : 0.45
    scale: m.pressed ? 0.97 : 1.0
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    color: {
        if (kind === "primary")   return m.containsMouse ? Theme.btnPrimaryHi : Theme.btnPrimary
        if (kind === "secondary") return m.containsMouse ? Theme.btnSecHi : Theme.btnSec
        return m.containsMouse ? Theme.panel2 : "transparent"   // ghost
    }
    Behavior on color { ColorAnimation { duration: 120 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 9
        Image {
            visible: btn.iconSource !== ""
            source: btn.iconSource
            sourceSize.width: btn.iconSize; sourceSize.height: btn.iconSize; smooth: true
        }
        Text {
            visible: btn.text !== ""
            text: btn.text
            color: btn.kind === "ghost" && !m.containsMouse ? Theme.subtext : btn.fg
            font.pixelSize: btn.fontSize; font.bold: true
        }
    }

    MouseArea {
        id: m
        anchors.fill: parent; hoverEnabled: true
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (btn.enabled) btn.clicked()
    }

    ToolTip.visible: btn.tooltip !== "" && m.containsMouse
    ToolTip.text: btn.tooltip
    ToolTip.delay: 400
}
