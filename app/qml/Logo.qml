import QtQuick
import QtQuick.Layouts
import SwiftIPTV

// Logo SwiftIPTV: marca vetorial (play + linhas de velocidade num quadrado
// roxo) + wordmark "Swift" (branco) + "IPTV" (roxo). Substitui a logo antiga.
Row {
    id: logo
    property real markSize: 32
    property int  fontSize: 20
    property bool showWordmark: true
    spacing: markSize * 0.34

    Image {
        anchors.verticalCenter: parent.verticalCenter
        source: "qrc:/qt/qml/SwiftIPTV/resources/logos/logo-swift.svg"
        sourceSize.width: logo.markSize
        sourceSize.height: logo.markSize
        smooth: true
    }

    Row {
        visible: logo.showWordmark
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Text {
            text: "Swift"
            color: Theme.text
            font.pixelSize: logo.fontSize
            font.bold: true
            font.letterSpacing: 0.5
        }
        Text {
            text: "IPTV"
            color: Theme.brand
            font.pixelSize: logo.fontSize
            font.bold: true
            font.letterSpacing: 0.5
        }
    }
}
