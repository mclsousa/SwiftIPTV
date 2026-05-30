import QtQuick
import QtQuick.Layouts
import SwiftIPTV

// Botão premium reutilizável (estilo aplicativo, não web).
//   kind: "primary"  -> preenchido com gradiente roxo
//         "secondary"-> superfície sólida com borda sutil
//         "ghost"    -> transparente, realça no hover
// Suporta ícone opcional à esquerda. Feedback de hover (leve zoom/realce) e
// press (encolhe). NÃO redeclara 'enabled' (usa o herdado de Item).
Rectangle {
    id: btn
    property string text: ""
    property string iconSource: ""
    property string kind: "primary"
    property int fontSize: 14
    signal clicked()

    implicitHeight: 48
    implicitWidth: row.implicitWidth + (kind === "ghost" ? 24 : 40)
    radius: 12
    clip: true
    color: kind === "secondary" ? (m.containsMouse ? Theme.panel2 : Theme.panel)
           : (kind === "ghost" ? (m.containsMouse ? Theme.panel2 : "transparent") : "transparent")
    border.color: kind === "secondary" ? Theme.border : "transparent"
    border.width: kind === "secondary" ? 1 : 0
    opacity: btn.enabled ? 1.0 : 0.45
    scale: m.pressed ? 0.97 : (m.containsMouse ? 1.02 : 1.0)
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 130 } }

    // Preenchimento gradiente do primário
    Rectangle {
        anchors.fill: parent; radius: 12; visible: btn.kind === "primary"
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: m.pressed ? Theme.grad2 : Theme.grad1 }
            GradientStop { position: 1.0; color: Theme.grad2 }
        }
    }
    // Realce no hover (só primário)
    Rectangle {
        anchors.fill: parent; radius: 12; color: "#ffffff"
        opacity: (m.containsMouse && btn.kind === "primary") ? 0.10 : 0
        Behavior on opacity { NumberAnimation { duration: 130 } }
    }

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
            color: btn.kind === "ghost" && !m.containsMouse ? Theme.subtext : Theme.text
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
