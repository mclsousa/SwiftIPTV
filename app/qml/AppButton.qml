import QtQuick
import QtQuick.Layouts
import SwiftIPTV

// Botão premium estilo HBO Max:
//   kind "primary"   -> preenchido BRANCO, texto/ícone escuros (ação principal)
//   kind "secondary" -> branco translúcido, texto/ícone brancos
//   kind "ghost"     -> transparente, realça no hover
// Ícone opcional à esquerda. Hover (leve zoom) e press (encolhe).
// NÃO redeclara 'enabled' (usa o herdado de Item).
Rectangle {
    id: btn
    property string text: ""
    property string iconSource: ""
    property string kind: "primary"
    property int fontSize: 14
    signal clicked()

    readonly property color fg: kind === "primary" ? "#0a0a0a" : Theme.text

    implicitHeight: 48
    implicitWidth: row.implicitWidth + (kind === "ghost" ? 24 : 44)
    radius: height / 2
    opacity: btn.enabled ? 1.0 : 0.45
    scale: m.pressed ? 0.97 : (m.containsMouse ? 1.02 : 1.0)
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    color: {
        if (kind === "primary")   return m.containsMouse ? "#e6e6e6" : "#ffffff"
        if (kind === "secondary") return Qt.rgba(1, 1, 1, m.containsMouse ? 0.26 : 0.14)
        return m.containsMouse ? Theme.panel2 : "transparent"   // ghost
    }
    Behavior on color { ColorAnimation { duration: 130 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 9
        Image {
            visible: btn.iconSource !== ""
            source: btn.iconSource
            sourceSize.width: 18; sourceSize.height: 18; smooth: true
        }
        Text {
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
}
