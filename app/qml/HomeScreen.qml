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
    property var    recentM: []
    property var    recentS: []
    property var    recentP: []   // continuar assistindo
    property var    launchM: []   // lançamentos (categoria do provedor)
    property string launchCat: ""

    // HERO rotativo: passa pelos filmes de Lançamentos (ou recém-adicionados).
    property var    heroItems: []
    property int    heroIndex: 0
    property real   heroAlpha: 1     // animado no crossfade da troca
    readonly property bool heroRotates: root.heroItems.length > 1
    readonly property var featured: (root.heroItems && root.heroIndex >= 0
                                     && root.heroIndex < root.heroItems.length)
                                    ? root.heroItems[root.heroIndex] : null

    function goHero(idx) {
        if (root.heroItems.length === 0) return
        var n = ((idx % root.heroItems.length) + root.heroItems.length) % root.heroItems.length
        if (n === root.heroIndex) return
        heroFade.to = n
        heroFade.restart()
    }

    // Troca automática a cada ~7s (pausa enquanto um título está em reprodução).
    Timer {
        interval: 7000; repeat: true
        running: root.heroRotates && !playerOverlay.active
        onTriggered: root.goHero(root.heroIndex + 1)
    }
    // Crossfade: esmaece -> troca o índice -> reaparece.
    SequentialAnimation {
        id: heroFade
        property int to: 0
        NumberAnimation { target: root; property: "heroAlpha"; to: 0; duration: 320; easing.type: Easing.InOutQuad }
        ScriptAction { script: root.heroIndex = heroFade.to }
        NumberAnimation { target: root; property: "heroAlpha"; to: 1; duration: 460; easing.type: Easing.InOutQuad }
    }

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
        // Banner passa pelos LANÇAMENTOS (fallback: recém-adicionados). Limita a
        // 8 pra rotação não ficar longa demais.
        var src = (root.launchM && root.launchM.length > 0) ? root.launchM : root.recentM
        root.heroItems = src ? src.slice(0, 8) : []
        root.heroIndex = 0
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
                    Layout.preferredHeight: 430

                    // 1) Arte ambiente em tela cheia (derivada da capa do título),
                    //    escurecida com scrims pra leitura — visual cinematográfico.
                    Item {
                        anchors.fill: parent
                        clip: true
                        visible: root.hasFeatured
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            verticalAlignment: Image.AlignTop
                            asynchronous: true; cache: true; smooth: true; mipmap: true
                            source: root.hasFeatured && root.featured.logo ? root.featured.logo : ""
                            opacity: 0.55 * root.heroAlpha   // crossfade da rotação
                        }
                        // Scrim horizontal: esquerda sólida (texto legível) -> direita revela a arte
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient { orientation: Gradient.Horizontal
                                GradientStop { position: 0.0;  color: Theme.bg }
                                GradientStop { position: 0.45; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.45) }
                                GradientStop { position: 1.0;  color: "transparent" } }
                        }
                        // Scrim vertical: base funde nos carrosséis abaixo
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0;  color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.35) }
                                GradientStop { position: 0.55; color: "transparent" }
                                GradientStop { position: 1.0;  color: Theme.bg } }
                        }
                    }

                    // brilho de destaque (halo da marca)
                    Rectangle {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: -80
                        width: 660; height: 660; radius: 330; opacity: 0.18
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.brand }
                            GradientStop { position: 0.62; color: "#00000000" }
                        }
                    }

                    // 2) Poster NÍTIDO em destaque (direita), com halo/elevação
                    Item {
                        visible: root.hasFeatured
                        opacity: root.heroAlpha
                        anchors.right: parent.right; anchors.rightMargin: 80
                        anchors.verticalCenter: parent.verticalCenter
                        width: 248; height: 366
                        scale: 1.0
                        SequentialAnimation on scale { loops: Animation.Infinite
                            NumberAnimation { to: 1.025; duration: 3400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0;   duration: 3400; easing.type: Easing.InOutSine } }
                        // halo suave atrás do card
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 40; height: parent.height + 40; radius: 28
                            color: Theme.brand; opacity: 0.20
                        }
                        Rectangle {
                            anchors.fill: parent; radius: 16
                            color: Theme.panel; clip: true
                            border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                            Image {
                                anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                                asynchronous: true; cache: true; smooth: true; mipmap: true
                                source: root.hasFeatured && root.featured.logo ? root.featured.logo : ""
                                visible: source != ""
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.left: parent.left; anchors.leftMargin: 48
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(640, parent.width * 0.55)
                        spacing: 15

                        Logo { markSize: 34; fontSize: 24 }

                        RowLayout {
                            spacing: 10
                            visible: root.hasFeatured
                            opacity: root.heroAlpha
                            Rectangle {
                                implicitWidth: novoTxt.implicitWidth + 18; height: 24; radius: 4
                                color: Theme.brand
                                Text { id: novoTxt; anchors.centerIn: parent; text: "LANÇAMENTO"
                                    color: "white"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1 }
                            }
                            Text {
                                text: "Filme"; color: Theme.subtext; font.pixelSize: 12; font.bold: true
                                font.letterSpacing: 1
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            opacity: root.hasFeatured ? root.heroAlpha : 1
                            text: root.hasFeatured ? root.featured.name
                                  : "Tudo o que você quer assistir,\nnum só lugar."
                            color: Theme.text; font.pixelSize: root.hasFeatured ? 42 : 36
                            font.bold: true; lineHeight: 1.04; wrapMode: Text.WordWrap
                            maximumLineCount: 3; elide: Text.ElideRight
                            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                        }
                        Text {
                            Layout.fillWidth: true
                            opacity: root.hasFeatured ? root.heroAlpha : 1
                            text: root.hasFeatured
                                  ? "Adicionado recentemente ao seu catálogo. Aperte play e comece a assistir."
                                  : "Canais ao vivo, filmes e séries em alta qualidade."
                            color: Theme.subtext; font.pixelSize: 16; wrapMode: Text.WordWrap
                            maximumLineCount: 2; elide: Text.ElideRight
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

                    // Pontos de navegação da rotação (clicáveis)
                    Row {
                        visible: root.heroRotates
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                        anchors.left: parent.left; anchors.leftMargin: 48
                        spacing: 7
                        Repeater {
                            model: root.heroItems.length
                            delegate: Rectangle {
                                required property int index
                                width: index === root.heroIndex ? 22 : 8
                                height: 8; radius: 4
                                color: index === root.heroIndex ? Theme.brand : Qt.rgba(1, 1, 1, 0.30)
                                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true; onClicked: root.goHero(index) }
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
