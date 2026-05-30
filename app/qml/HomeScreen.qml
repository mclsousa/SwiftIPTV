import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

// Home — vitrine estilo streaming: barra de topo + HERO em destaque (1º filme,
// com Reproduzir) + carrosséis de Filmes e Séries. Tocar funciona direto da
// Home (PlayerOverlay). Fundo aurora vem do Main.qml.
Item {
    id: root
    anchors.fill: parent
    opacity: 0
    NumberAnimation on opacity { from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }

    property string movieCat: ""
    property string seriesCat: ""
    property var    featured: null

    function refreshFeatured() {
        if (channels.movieCategoriesModel.count > 0)
            root.movieCat = channels.movieCategoriesModel.data(channels.movieCategoriesModel.index(0,0), Qt.UserRole+1)
        if (channels.seriesCategoriesModel.count > 0)
            root.seriesCat = channels.seriesCategoriesModel.data(channels.seriesCategoriesModel.index(0,0), Qt.UserRole+1)
        if (root.movieCat !== "") {
            var arr = channels.moviesInCategory(root.movieCat, 1)
            root.featured = (arr && arr.length > 0) ? arr[0] : null
        }
    }
    Component.onCompleted: refreshFeatured()
    Connections {
        target: channels
        function onListReady(n) { Window.window.notify(n + " canais carregados"); root.refreshFeatured() }
        function onError(m) { Window.window.notify(m) }
    }

    readonly property bool hasFeatured: root.featured && root.featured.id

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            Layout.fillWidth: true
            active: "home"
            showSearch: false
            onTabClicked: function(key) {
                if (playerOverlay.active) playerOverlay.stop()
                if (key === "live")         app.navigate("player")
                else if (key === "movies")  app.navigate("movies")
                else if (key === "series")  app.navigate("series")
                else if (key === "profile") app.navigate("settings")
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }

            ColumnLayout {
                id: col
                width: parent.width
                spacing: 26

                // ---------- HERO ----------
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 380

                    // brilho de destaque
                    Rectangle {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: -60
                        width: 640; height: 640; radius: 320; opacity: 0.20
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.brand }
                            GradientStop { position: 0.6; color: "#00000000" }
                        }
                    }

                    // Poster do título em destaque (direita)
                    Rectangle {
                        visible: root.hasFeatured
                        anchors.right: parent.right; anchors.rightMargin: 70
                        anchors.verticalCenter: parent.verticalCenter
                        width: 232; height: 340; radius: 14
                        color: Theme.panel; border.color: Theme.border; clip: true
                        scale: 1.0
                        SequentialAnimation on scale { loops: Animation.Infinite
                            NumberAnimation { to: 1.03; duration: 3200; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0;  duration: 3200; easing.type: Easing.InOutSine } }
                        Image {
                            anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            source: root.hasFeatured && root.featured.logo ? root.featured.logo : ""
                            visible: source != ""
                        }
                    }
                    // Marca decorativa quando não há destaque
                    Image {
                        visible: !root.hasFeatured
                        anchors.right: parent.right; anchors.rightMargin: 110
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/qt/qml/SwiftIPTV/resources/logos/logo-swift.svg"
                        sourceSize.width: 200; sourceSize.height: 200; opacity: 0.9
                    }

                    ColumnLayout {
                        anchors.left: parent.left; anchors.leftMargin: 44
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(620, parent.width * 0.55)
                        spacing: 14

                        Logo { markSize: 34; fontSize: 24 }

                        Text {
                            visible: root.hasFeatured
                            text: "EM DESTAQUE"
                            color: Theme.brand; font.pixelSize: 13; font.bold: true; font.letterSpacing: 2
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.hasFeatured ? root.featured.name
                                  : "Tudo o que você quer assistir,\nnum só lugar."
                            color: Theme.text; font.pixelSize: root.hasFeatured ? 38 : 36
                            font.bold: true; lineHeight: 1.05; wrapMode: Text.WordWrap
                            maximumLineCount: 3; elide: Text.ElideRight
                        }
                        Text {
                            text: "Canais ao vivo, filmes e séries em alta qualidade."
                            color: Theme.subtext; font.pixelSize: 16
                        }
                        RowLayout {
                            spacing: 14
                            Layout.topMargin: 6
                            HeroButton {
                                label: root.hasFeatured ? "Reproduzir" : "Assistir TV ao Vivo"
                                primary: true
                                onClicked: {
                                    if (root.hasFeatured) playerOverlay.play(root.featured.id)
                                    else app.navigate("player")
                                }
                            }
                            HeroButton {
                                label: "Explorar Filmes"; primary: false
                                onClicked: app.navigate("movies")
                            }
                        }
                    }
                }

                CarouselRow {
                    Layout.fillWidth: true
                    title: "Filmes em destaque" + (root.movieCat ? "  ·  " + root.movieCat : "")
                    items: root.movieCat ? channels.moviesInCategory(root.movieCat, 20) : []
                    posterField: "logo"
                    onClickedItem: function(item) { playerOverlay.play(item.id) }
                    onSeeAll: app.navigate("movies")
                }

                CarouselRow {
                    Layout.fillWidth: true
                    title: "Séries" + (root.seriesCat ? "  ·  " + root.seriesCat : "")
                    items: root.seriesCat ? channels.seriesInCategory(root.seriesCat) : []
                    posterField: "poster"
                    onClickedItem: function(item) { app.navigate("series") }
                    onSeeAll: app.navigate("series")
                }

                Item { Layout.fillWidth: true; Layout.preferredHeight: 4 }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 18
                    text: auth.expiresAt ? ("Vencimento: " + auth.expiresAt) : ""
                    color: Theme.subtext; font.pixelSize: 13; font.bold: true
                }
            }
        }
    }

    PlayerOverlay { id: playerOverlay }

    component HeroButton: Rectangle {
        id: hb
        property string label: ""
        property bool primary: true
        signal clicked()
        implicitWidth: hbTxt.implicitWidth + 44
        implicitHeight: 50
        radius: 25
        color: primary ? "transparent" : (hbMouse.containsMouse ? Theme.panel2 : Theme.panel)
        border.color: primary ? "transparent" : Theme.border
        border.width: primary ? 0 : 1
        scale: hbMouse.containsMouse ? 1.03 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }
        clip: true
        Rectangle {
            anchors.fill: parent; radius: 25; visible: hb.primary
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: hbMouse.pressed ? Theme.grad2 : Theme.grad1 }
                GradientStop { position: 1.0; color: Theme.grad2 }
            }
        }
        Text { id: hbTxt; anchors.centerIn: parent; text: hb.label; z: 1
            color: Theme.text; font.pixelSize: 15; font.bold: true }
        MouseArea { id: hbMouse; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor; onClicked: hb.clicked() }
    }

    component CarouselRow: ColumnLayout {
        id: cr
        property string title: ""
        property var items: []
        property string posterField: "logo"
        signal clickedItem(var item)
        signal seeAll()
        spacing: 8
        visible: items.length > 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 28; Layout.rightMargin: 28
            Text { text: cr.title; color: Theme.text; font.pixelSize: 19; font.bold: true }
            Item { Layout.fillWidth: true }
            Text { text: "Ver todos  ›"; color: saMouse.containsMouse ? Theme.brand : Theme.subtext
                font.pixelSize: 13; font.bold: true
                MouseArea { id: saMouse; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: cr.seeAll() } }
        }
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: 232
            orientation: ListView.Horizontal
            leftMargin: 28; rightMargin: 28; spacing: 14
            clip: true; cacheBuffer: 600
            boundsBehavior: Flickable.StopAtBounds
            model: cr.items
            delegate: Item {
                required property var modelData
                width: 140; height: 232
                Column {
                    anchors.fill: parent; spacing: 6
                    Rectangle {
                        width: parent.width; height: 196; radius: 12; color: Theme.panel; clip: true
                        border.color: hpMouse.containsMouse ? Theme.brand : "transparent"; border.width: 2
                        scale: hpMouse.containsMouse ? 1.06 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            source: modelData[cr.posterField] ? modelData[cr.posterField] : ""
                            visible: source != "" }
                    }
                    Text { width: parent.width; text: modelData.name; color: Theme.textDim
                        font.pixelSize: 12; elide: Text.ElideRight; maximumLineCount: 2
                        wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
                }
                MouseArea { id: hpMouse; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: cr.clickedItem(modelData) }
            }
        }
    }
}
