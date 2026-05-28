pragma Singleton
import QtQuick

// Paleta TV DIG+: preto profundo + amarelo dourado do logo,
// com cinzas neutros para cards e bordas. Pensada pra hexágono
// sutil ao fundo via Image (resources/patterns/hexagons.svg).
QtObject {
    // --- Fundos ---
    readonly property color bg:      "#0a0a0a"   // base, quase preto
    readonly property color panel:   "#1a1a1a"   // cards / sidebar
    readonly property color panel2:  "#252525"   // hover / divisões
    readonly property color border:  "#2a2a2a"   // linhas finas

    // --- Marca (amarelo dourado do logo TV DIG+) ---
    readonly property color brand:   "#FFC107"   // ícones e destaques principais
    readonly property color brand2:  "#FFA000"   // hover / pressionado
    readonly property color brandSoft: "#332700" // versão escurecida pra fundo sutil

    // --- Texto ---
    readonly property color text:     "#ffffff"  // título principal
    readonly property color textDim:  "#d0d6e0"  // texto normal
    readonly property color subtext:  "#8a8f9b"  // legenda / contagens

    // --- Status ---
    readonly property color ok:      "#22c55e"
    readonly property color warn:    "#fbbf24"
    readonly property color bad:     "#ef4444"

    // --- Botões amarelos (texto preto pra contraste) ---
    readonly property color buttonText: "#0a0a0a"
}
