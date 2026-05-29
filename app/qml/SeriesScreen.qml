import SwiftIPTV

// Tela de Séries — usa o navegador genérico VodBrowser com os modelos de
// séries do ChannelManager (canais classificados como "series").
VodBrowser {
    tabKey: "series"
    kindLabel: "Séries"
    listModel: channels.seriesModel
    categoryModel: channels.seriesCategoriesModel
    fallbackIcon: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/series.svg"
}
