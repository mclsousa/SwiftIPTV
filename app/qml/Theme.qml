pragma Singleton
import QtQuick

// Paleta TV DIG+ — redesign "HBO Max": preto profundo com leve tom roxo,
// destaque em violeta e gradiente roxo/índigo. Ícones em branco, logo dourada
// mantida como marca. Tipografia/raios pensados para um visual cinematográfico.
QtObject {
    // --- Fundos (escuro com leve tom arroxeado) ---
    readonly property color bg:      "#0B0910"   // base
    readonly property color bg2:     "#050409"   // base mais escura (gradiente)
    readonly property color panel:   "#17131F"   // cards / superfícies
    readonly property color panel2:  "#221B30"   // hover / divisões
    readonly property color border:  "#2C2440"   // linhas finas

    // --- Marca / destaque (violeta HBO) ---
    readonly property color brand:    "#8B5CF6"   // destaque principal
    readonly property color brand2:   "#A78BFA"   // hover (mais claro)
    readonly property color brandSoft:"#1E1633"   // fundo sutil arroxeado
    // Gradiente roxo -> índigo (botões, hero, destaques)
    readonly property color grad1:    "#7C3AED"   // violeta
    readonly property color grad2:    "#4F46E5"   // índigo

    // --- Texto ---
    readonly property color text:     "#ffffff"
    readonly property color textDim:  "#CFCAD9"
    readonly property color subtext:  "#8E8A9C"

    // --- Status ---
    readonly property color ok:      "#22c55e"
    readonly property color warn:    "#fbbf24"
    readonly property color bad:     "#ef4444"

    // --- Texto sobre botões de destaque (roxo) ---
    readonly property color buttonText: "#ffffff"
}
