import SwiftIPTV

// Tela de Filmes (VOD) — usa o navegador genérico VodBrowser com os
// modelos de filmes do ChannelManager (canais classificados como "movie").
VodBrowser {
    tabKey: "movies"
    kindLabel: "Filmes"
    listModel: channels.moviesModel
    categoryModel: channels.movieCategoriesModel
    fallbackIcon: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/movie.svg"
}
