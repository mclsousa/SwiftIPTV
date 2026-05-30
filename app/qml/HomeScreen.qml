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
    property var    recentM: []
    property var    recentS: []
    property var    recentP: []   // continuar assistindo
    property var    launchM: []   // lançamentos (categoria do provedor)
    property string launchCat: ""

    function refreshFeatured() {
        if (channels.movieCategoriesModel.count > 0)
            root.movieCat = channels.movieCategoriesModel.data(channels.movieCategoriesModel.index(0,0), Qt.UserRole+1)
        if (channels.seriesCategoriesModel.count > 0)
            root.seriesCat = channels.seriesCategoriesModel.data(channels.seriesCategoriesModel.index(0,0), Qt.UserRole+1)
        root.recentM = channels.recentMovies(20)
        root.recentS = channels.recentSeries(20)
        root.recentP = channels.recentlyPlayed(20)
        root.launchM = channels.launchMovies(20)
        root.launchCat = channels.launchCategoryName()
        // Banner em destaque = ÚLTIMO filme adicionado (atualiza a cada recarga).
        root.featured = (root.recentM && root.recentM.length > 0) ? root.recentM[0] : null
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
                if (key === "live")           app.navigate("player")
                else if (key === "favorites") app.navigate("favorites")
                else if (key === "movies")    app.navigate("movies")
                else if (key === "series")    app.navigate("series")
                else if (key === "profile")   app.navigate("settings")
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
                    ColumnLayout {
                        anchors.left: parent.left; anchors.leftMargin: 44
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(620, parent.width * 0.55)
                        spacing: 14

                        Logo { markSize: 34; fontSize: 24 }

                        Rectangle {
                            visible: root.hasFeatured
                            implicitWidth: novoTxt.implicitWidth + 18; height: 24; radius: 4
                            color: Theme.brand
                            Text { id: novoTxt; anchors.centerIn: parent; text: "EM DESTAQUE"
                                color: "white"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1 }
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
                            spacing: 12
                            Layout.topMargin: 6
                            AppButton {
                                kind: "primary"; fontSize: 15
                                text: root.hasFeatured ? "Reproduzir" : "Assistir TV ao Vivo"
                                iconSource: root.hasFeatured ? "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/play_dark.svg" : ""
                                onClicked: {
                                    if (root.hasFeatured) playerOverlay.play(root.featured.id, root.featured.name, root.featured.logo)
                                    else app.navigate("player")
                                }
                            }
                            AppButton {
                                kind: "secondary"; fontSize: 15
                                text: "Explorar Filmes"
                                onClicked: app.navigate("movies")
                            }
                        }
                    }
                }

                CarouselRow {
                    Layout.fillWidth: true
                    title: "Continuar assistindo"
                    items: root.recentP
                    posterField: "logo"
                    onClickedItem: function(item) { playerOverlay.play(item.id, item.name, item.logo) }
                    onSeeAll: {}
                }

                // Único carrossel com a etiqueta NOVO (Lançamentos)
                CarouselRow {
                    Layout.fillWidth: true
                    title: "Lançamentos"
                    items: root.launchM
                    posterField: "logo"
                    showNew: true
                    onClickedItem: function(item) { playerOverlay.play(item.id, item.name, item.logo) }
                    onSeeAll: { if (root.launchCat !== "") app.navigate("movies") }
                }

                CarouselRow {
                    Layout.fillWidth: true
                    title: "Filmes adicionados recentemente"
                    items: root.recentM
                    posterField: "logo"
                    onClickedItem: function(item) { playerOverlay.play(item.id, item.name, item.logo) }
                    onSeeAll: app.navigate("movies")
                }

                CarouselRow {
                    Layout.fillWidth: true
                    title: "Séries adicionadas recentemente"
                    items: root.recentS
                    posterField: "poster"
                    onClickedItem: function(item) { app.navigate("series") }
                    onSeeAll: app.navigate("series")
                }

                CarouselRow {
                    Layout.fillWidth: true
                    title: "Filmes em destaque" + (root.movieCat ? "  ·  " + root.movieCat : "")
                    items: root.movieCat ? channels.moviesInCategory(root.movieCat, 20) : []
                    posterField: "logo"
                    onClickedItem: function(item) { playerOverlay.play(item.id, item.name, item.logo) }
                    onSeeAll: app.navigate("movies")
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

    component CarouselRow: ColumnLayout {
        id: cr
        property string title: ""
        property var items: []
        property string posterField: "logo"
        property bool showNew: false        // exibe etiqueta "NOVO" nos cards
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
                            asynchronous: true; cache: true; smooth: true; mipmap: true
                            source: modelData[cr.posterField] ? modelData[cr.posterField] : ""
                            visible: source != "" }
                        // Etiqueta NOVO (recém-adicionados)
                        Rectangle {
                            visible: cr.showNew
                            anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 7
                            implicitWidth: novoCard.implicitWidth + 12; height: 20; radius: 4
                            color: Theme.brand
                            Text { id: novoCard; anchors.centerIn: parent; text: "NOVO"
                                color: "white"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.5 }
                        }
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
