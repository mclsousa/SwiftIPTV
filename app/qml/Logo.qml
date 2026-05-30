import QtQuick
import SwiftIPTV

// Logo SwiftIPTV — wordmark puro (sem símbolo): "Swift" branco + "IPTV" roxo,
// peso forte e tracking levemente apertado pra um visual moderno e profissional.
Row {
    id: logo
    // 'markSize' mantido por compatibilidade com chamadas antigas (não usado).
    property real markSize: 32
    property int  fontSize: 20
    property bool showWordmark: true

    spacing: 0

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Swift"
        color: Theme.text
        font.pixelSize: logo.fontSize
        font.weight: Font.Black
        font.letterSpacing: -0.5
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "IPTV"
        color: Theme.brand
        font.pixelSize: logo.fontSize
        font.weight: Font.Black
        font.letterSpacing: -0.5
    }
}
