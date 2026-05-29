# Design — Tela TV ao Vivo (3 colunas) — DIGTV+

**Data:** 2026-05-28
**Versão alvo:** v1.20
**Status:** aprovado para implementação

## Contexto

O redesign visual TV DIG+ está em andamento. Já feitas: tema (v1.18) e
HomeScreen / hub de cards (v1.19). Faltam 4 telas para igualar os modelos
fornecidos pelo cliente: **TV ao Vivo**, **Filmes**, **Séries** e
**Configurações**.

Estratégia acordada: **incremental, uma tela por versão**. Esta spec cobre
apenas a **primeira tela: TV ao Vivo (layout de 3 colunas)**.

### Estado atual relevante

- A lista de canais vem de um único M3U (`m3u_plus`) baixado via failover de
  `server_dns` e cacheado em disco. `M3UParser` extrai `tvg-id`, `tvg-name`,
  `tvg-logo`, `group-title` e a URL do stream.
- O M3U é um **Xtream Codes** e mistura, na mesma lista (~147 mil itens):
  - **TV ao vivo** (~2.118): URL `http://host/USER/PASS/ID`
  - **Filmes** (~16.774): URL `http://host/movie/USER/PASS/ID.mp4`
  - **Séries/episódios** (~128.692): URL `http://host/series/USER/PASS/ID.mp4`
- A tela atual (`MainPlayer.qml`) é de **2 colunas** (sidebar busca+abas+lista |
  player em tela cheia com auto-hide). O player mpv (janela filha Win32 + D3D11)
  está **validado e estável** desde a v1.11–v1.16.
- `EPGManager` carrega o XMLTV inteiro em memória (`channelId -> [Programme]`
  ordenados) mas só expõe o programa **atual** (`currentTitle/Times/Progress`).

### Fonte de dados — decisão (Abordagem A)

A TV ao Vivo continua usando o **M3U já baixado**, filtrando para mostrar
**apenas canais ao vivo**. Filmes/Séries usarão a API Xtream (`player_api.php`,
já verificada como disponível) em versões futuras — não nesta.

Motivo: menor risco, preserva o player mpv validado e o EPG (que casa por
`tvg-id`), funciona offline pelo cache, e resolve a poluição da lista de uma vez.

## Modelo visual (referência do cliente)

```
┌─────────────────────────────────────────────────────────────────────┐
│  Home   TV ao Vivo   Filmes   Séries        🔍 [busca]       TV DIG+  │  barra de topo
├──────────────┬──────────────────────┬─────────────────────────────────┤
│ CATEGORIAS   │ CANAIS (da categoria)│   ┌─────────────────────────┐   │
│ Premiere 96  │ 805 Premiere FHD     │   │       VÍDEO (mpv)       │   │
│ PPV       63 │ 806 Premiere FHD*    │   └─────────────────────────┘   │
│ Estaduais  4 │ 807 Premiere H265    │   PREMIERE CLUBES FHD            │
│ Disney+   14 │ 808 ...              │   19:15~23:15  Programação… (●)  │
│ ...          │ ...                  │   23:15~03:15  Programação…      │
│              │                      │   [Playback][+Favoritos][Procurar]│
└──────────────┴──────────────────────┴─────────────────────────────────┘
```

## Arquitetura

### Layout e navegação

- **Barra de topo (`TopNav.qml`, reutilizável):** abas
  `Home · TV ao Vivo · Filmes · Séries` + campo de busca + logo TV DIG+ à
  direita. Aba ativa em amarelo (`Theme.brand`).
  - `Home` → `app.navigate("home")`
  - `TV ao Vivo` → ativa (tela atual)
  - `Filmes` / `Séries` → `Window.window.notify("… (em construção)")` por
    enquanto; serão ligadas nas próximas versões.
  - Campo de busca → filtra os canais da categoria selecionada.
- **Coluna 1 — Categorias (`CategorySidebar.qml`, reutilizável), ~300px:**
  `group-title` distintos **dos canais ao vivo**, cada um com a contagem de
  canais. Item selecionado em amarelo. Clique seleciona a categoria.
- **Coluna 2 — Canais:** canais da categoria selecionada (número + logo + nome).
  Item em reprodução em amarelo. Clique → reproduz. Duplo-clique → reproduz +
  tela cheia.
- **Coluna 3 — Player + EPG + botões:** vídeo mpv (painel 16:9 no topo), nome do
  canal atual, lista de programas do EPG (atual + próximos; atual em amarelo com
  marcador), e os 3 botões.

### Camada de dados (C++)

1. **`Channel.type`** — novo campo `enum/QString` em `M3UParser.h`.
   `M3UParser::parse` classifica pela URL do stream:
   - contém `/movie/` → `"movie"`
   - contém `/series/` → `"series"`
   - caso contrário → `"live"`
2. **`ChannelManager`** ganha:
   - **Modelo de categorias ao vivo** (`liveCategoriesModel`): lista de grupos
     distintos entre canais `type=="live"`, cada um com `name` e `count`.
     Implementado como um `QAbstractListModel` simples (ou `QStringListModel`
     com role de contagem). Recalculado em `rebuildAuxModels()`.
   - **Filtro por categoria + tipo live** no modelo de canais. Abordagem:
     adicionar a `ChannelListModel` uma propriedade `categoryFilter` (string) e
     fazer `rebuild()` restringir `m_visible` aos canais cujo `group ==
     categoryFilter` **e** `type == "live"`. O filtro de texto existente é
     combinado (AND) com o de categoria.
   - Observação: o filtro de tipo `live` vale para o modelo principal usado na
     TV ao Vivo. Favoritos/Histórico continuam como estão (podem conter
     qualquer tipo; fora de escopo desta tela).
3. **`EPGManager::upcoming(channelId, n)`** — `Q_INVOKABLE` que retorna
   `QVariantList` dos próximos `n` programas a partir de agora, cada um como
   `{ "times": "HH:mm ~ HH:mm", "title": ..., "current": bool }`. Dados já
   existem em `m_guide`; só itera a partir do programa atual.

### Comportamento

- **Seleção de categoria** filtra a coluna de canais (via `categoryFilter`).
- **Seleção de canal** chama o caminho de reprodução atual (`player.playById`)
  e atualiza nome + EPG na coluna 3.
- **Favoritos:** botão chama `channels.toggleFavorite(id)`; rótulo alterna entre
  "Adicionar aos Favoritos" / "Remover dos Favoritos" conforme
  `channels.isFavorite(id)`.
- **Procurar:** foca o campo de busca do topo.
- **Playback:** stub — `Window.window.notify("Playback (em construção)")`.
- **Tela cheia:** duplo-clique no vídeo → fullscreen real escondendo tudo
  (mantém comportamento da v1.16, incluindo forward de `WM_LBUTTONDBLCLK` da
  janela nativa). Em modo janela, as 3 colunas ficam **sempre visíveis** — o
  auto-hide de 5s da v1.16 **não se aplica** neste layout (só fazia sentido no
  layout vídeo-em-tela-cheia anterior). Em fullscreen, esconde as colunas.

### Arquivos

- **Novos QML:**
  - `app/qml/LiveTV.qml` — a tela TV ao Vivo (assume o papel de tela `"player"`
    no `Loader` do `Main.qml`).
  - `app/qml/TopNav.qml` — barra de topo reutilizável.
  - `app/qml/CategorySidebar.qml` — coluna de categorias reutilizável.
- **`Main.qml`:** o case `"player"` passa a carregar `LiveTV.qml`.
- **`MainPlayer.qml`:** removido (substituído por `LiveTV.qml`) ou mantido como
  referência morta — preferência: remover para evitar confusão.
- **C++ tocado:** `M3UParser.{h,cpp}`, `ChannelManager.{h,cpp}`,
  `ChannelList.{h,cpp}` (o `ChannelListModel`), `EPGManager.{h,cpp}`.
- **NÃO tocar:** `StreamPlayer`, `PlayerWidget`, opções do mpv, tuning de
  qualidade/hwdec/cache. (Regra explícita do cliente.)
- **`CMakeLists.txt`:** registrar os novos QML no módulo se necessário.

## Tratamento de erros / casos de borda

- **EPG ausente** para o canal: a coluna 3 mostra só o nome do canal (sem lista
  de programas), sem quebrar layout.
- **Categoria sem canais após filtro de texto:** coluna de canais vazia, rodapé
  mostra "0 canais".
- **Canal indisponível:** mantém o estado `player.hasError` da v1.17
  ("⚠ Canal indisponível") dentro do painel de vídeo.
- **Lista ainda carregando:** categorias e canais aparecem conforme
  `listReady`; rodapé/estado de loading reaproveitado de `channels.loading`.
- **Cache antigo sem `type`:** ao reparsear o M3U, o `type` é recomputado; não
  há persistência do `type` em disco além do próprio M3U.

## Verificação

- Build local via CMake sem erros nem warnings novos.
- TV ao Vivo lista **apenas canais ao vivo** (~2.118), não ~147 mil.
- Categorias correspondem aos `group-title` dos canais live, com contagens
  corretas; clicar uma categoria filtra a coluna de canais.
- Clicar um canal reproduz pelo mesmo caminho mpv atual (sem regressão de
  qualidade/estabilidade).
- A coluna 3 mostra nome + EPG (atual + próximos) quando há guia.
- Botões: Favoritos alterna estado; Procurar foca a busca; Playback notifica
  "em construção".
- Duplo-clique no vídeo entra/sai de tela cheia.
- Publicação: `git tag v1.20 && git push --tags` → CI gera o release.

## Fora de escopo (versões futuras)

- Filmes (v1.21+): cliente Xtream `player_api.php`, grade de pôsteres, sidebar
  de categorias VOD, ordenar por adição.
- Séries (v1.22+): idem Filmes + agrupamento de episódios.
- Configurações (v1.23+): grade de cards de ajustes.
- Botão Playback funcional (catch-up/timeshift) — a definir.
