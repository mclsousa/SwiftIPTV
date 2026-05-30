# Changelog

Todas as mudanças relevantes do **SwiftIPTV** (painel + app).

> **Convenção (importante):** cada versão começa com um cabeçalho no formato
> `## v<versão> - AAAA-MM-DD`. O GitHub Actions extrai automaticamente o trecho
> entre `## v1.0` e o próximo `## ` e usa como descrição da Release da tag `v1.0`.

## Não lançado
- Anote aqui o que está em desenvolvimento antes de criar a próxima tag.

## v1.26 - 2026-05-29
**Polimento visual: logo nova, TV ao Vivo mais bonita, hero com destaque.**

### App Windows — `app/`
- **Logo refeita** (3ª iteração): agora um **raio** (lightning) com gradiente
  roxo/índigo — remete a "Swift" (velocidade), sem a "caixinha" anterior.
- **TV ao Vivo** mais bonita: canais sem logo deixam de mostrar um quadrado
  cinza vazio — exibem um ícone de TV elegante; logos com borda arredondada;
  estado "Selecione um canal" agora tem ícone; linhas mais premium.
- **Home com hero de destaque** (estilo streaming): o primeiro filme aparece
  como **destaque** (pôster + "Reproduzir") e toca direto da Home; os
  carrosséis de Filmes tocam no clique; Séries levam à seção.
- Player mpv **intocado**.

## v1.25 - 2026-05-29
**Salto visual: interface cinematográfica com animações.** Foco em
modernidade, profundidade e movimento.

### App Windows — `app/`
- **Fundo "aurora" animado**: blobs de luz roxa/índigo/violeta flutuando
  lentamente atrás de todo o conteúdo (puro QML, sutil e premium).
- **Logo SwiftIPTV refeita**: marca em squircle com gradiente, brilho (gloss)
  e play arredondado — mais identidade e acabamento.
- **Login cinematográfico**: card de vidro que surge com fade+escala (leve
  overshoot), logo com brilho pulsante, foco animado nos campos e botão em
  gradiente com realce no hover.
- **Home repensada** (removidos os 3 cards simples): **hero animado** com marca,
  tagline e chamadas pra ação + **carrosséis** de Filmes e Séries em destaque
  (estilo streaming).
- **Animações de entrada** em todas as telas (fade-in suave) e **indicador de
  aba animado** na barra de topo (cresce/desliza).
- **Micro-interações**: pôsteres e botões com elevação/zoom e brilho no hover.
- Configurações: fundo levemente translúcido pra revelar a aurora.
- Player mpv **intocado**.

## v1.24 - 2026-05-29
**Logo nova SwiftIPTV, TV ao Vivo redesenhada, navegação por categorias e
modais de áudio/legenda.** Continuação do redesign (sobre a v1.23).

### Marca
- **Nova logo SwiftIPTV criada do zero** (vetorial): marca roxa com play +
  linhas de velocidade + wordmark "Swift"+"IPTV" (`Logo.qml` + `logo-swift.svg`).
  Aposenta a logo antiga.
- **Renomeado "DIGTV+" → "SwiftIPTV"** em todo o app (título da janela, nome de
  exibição, Configurações, instalador).

### App Windows — `app/`
- **TV ao Vivo redesenhada** (estilo TiViMate/Pluto): lista de canais com
  **programa atual (EPG) + barra de progresso** por canal; coluna do player
  com EPG "agora/a seguir" destacado. O EPG foi mantido e ganhou destaque.
- **Filmes e Séries — navegação por categorias**: botão **"Ver todos"** em cada
  fileira (abre a grade completa da categoria) e **"Ver todas as categorias"**
  no canto superior direito (índice de todas as categorias).
- **Modais de Faixa de áudio e Legenda** no player: os ícones agora abrem um
  modal listando as faixas/legendas disponíveis do título atual para o usuário
  **escolher** (não apenas alternar). Inclui opção "Desligado" para legenda.
- **Login**: removido o link "Testar minha conexão".
- **Após o login vai direto para a Home** (sem a tela de DNS automática; DNS
  fica em Configurações → "Otimizar Minha Conexão").
- **Stop ao alternar** entre TV ao Vivo / Filmes / Séries.
- **Animação de "Recarregando lista"**: overlay com spinner ao recarregar a
  lista IPTV.
- **Backend**: `tvgId` exposto por canal (EPG na lista); `audioTracks()`/
  `subtitleTracks()`/`setAudioTrack`/`setSubtitleTrack` no player.
- Player mpv **intocado** (qualidade/hwdec/cache).

## v1.23 - 2026-05-29
**Redesign completo do visual — estilo HBO Max / Netflix.** Reformulação de
todas as telas para um visual cinematográfico, profissional e organizado.

### Tema
- **Nova paleta HBO Max**: preto profundo com leve tom roxo + destaque violeta
  (`#8B5CF6`) e gradiente roxo→índigo nos botões/destaques. Texto branco.
- **Fundo gradiente** cinematográfico (substitui o pattern hexagonal).
- **Ícones em branco** (recoloridos), destaque roxo; logo TV DIG+ mantida.
- Nova **barra de topo** (`TopBar.qml`) estilo streaming: logo + abas com
  indicador da aba ativa + busca + atalho de Conta/Configurações.

### App Windows — `app/`
- **Login redesenhado** (cinematográfico, brilho roxo, botão em gradiente).
  Removido o link "Testar minha conexão" da tela de login.
- **Ao logar, vai direto para a Home** — a tela "Otimizar sua conexão" (DNS)
  não aparece mais automaticamente (fica em Configurações → "Otimizar Minha
  Conexão").
- **Home premium**: três grandes cartões (TV ao Vivo / Filmes / Séries) +
  ações (Configurações / Recarregar / Sair).
- **Filmes — navegação estilo Netflix**: fileiras (carrosséis) horizontais de
  pôsteres por categoria; busca mostra uma grade de resultados; clicar abre o
  **player em tela cheia**.
- **Séries — fluxo completo**: carrosséis de séries por categoria → **tela de
  detalhes** (capa + seletor de temporada + lista de episódios com miniatura)
  → episódio abre o player. Resolve a organização ruim de temporadas/episódios.
- **Player em tela cheia** (`PlayerOverlay.qml`) com **controles bem
  espaçados**: anterior, −10s, play/pause, +10s, próximo, áudio, legenda, tela
  cheia, parar, voltar + barra de progresso. (O chrome fica fora do retângulo
  do vídeo por causa da janela nativa do mpv; em tela cheia some, ESC sai.)
- **Stop ao alternar** entre TV ao Vivo / Filmes / Séries (e ao abrir
  Configurações pela barra de topo).
- **Backend**: `moviesInCategory(categoria, limite)` e `searchSeries(texto)`
  para alimentar carrosséis e busca.
- Player mpv **intocado** (qualidade/hwdec/cache).

## v1.22 - 2026-05-29
**Player de VOD completo + Séries organizadas + Home alinhada.** Pacote de
melhorias a partir do feedback do uso real da v1.21.

### App Windows — `app/`
- **Filmes e Séries agora são telas de 3 colunas** (mesmo padrão da TV ao
  Vivo), permitindo navegar pelo catálogo enquanto um título toca:
  `categorias | títulos | player + controles`.
- **Player de VOD com controles completos** (`VodPlayerColumn.qml`):
  play/pause, parar, −10s/+10s, anterior/próximo, **faixa de áudio**,
  **legenda**, tela cheia, **barra de progresso** com tempo atual/total e
  botão voltar. Reaproveita o `StreamPlayer` (mpv intocado).
- **Séries organizadas em hierarquia** (corrige episódios "soltos"):
  categoria (SERIES A, B, …) → **série** (agrupada pelo nome, ex.: "Vikings
  [2013]") → **temporada** → **episódio**. O parser extrai nome/temporada/
  episódio do título (`S## E##`); novo índice no `ChannelManager`
  (`seriesInCategory` / `seasonsOf` / `episodesOf`).
- **Filmes**: coluna de categorias agora tem o atalho **"Tudo"** (todos os
  filmes) além das categorias do provedor.
- **HomeScreen realinhada** ao modelo: TV ao Vivo (card grande) à esquerda,
  grade 2×2 (Filmes/Séries/Conta/Servidores) e 3 pílulas (Configurações/
  Recarregar/Sair) à direita — os três blocos com a **mesma altura**. Agora
  usa os **ícones da marca TV DIG+** fornecidos pelo usuário (recoloridos
  para o amarelo do tema).
- **Configurações**: as opções de conexão viraram **"Testar Minha Conexão"**
  (diagnóstico) e **"Otimizar Minha Conexão"** (DNS), como cards.
- **Sem emoji** (regra do projeto): ícones de mídia (play/pause/stop/avançar/
  retroceder/anterior/próximo/áudio/legenda/tela cheia) adicionados como SVG.
- **Player mpv intocado**: sem mudança de qualidade/hwdec/cache/tuning.

## v1.21 - 2026-05-29
**Redesign Fases 4-6 juntas: Configurações + Filmes + Séries.** Fecha o
redesign visual TV DIG+ (todas as telas do hub agora existem).

### App Windows — `app/`
- **Nova `SettingsScreen.qml`** (tela de Configurações, acessível pela Home):
  título centralizado + voltar, grade de opções e rodapé com conta/MAC/versão.
  Opções: **Otimizar Conexão** (abre a tela de DNS), **Diagnóstico de Rede**
  (abre o diagnóstico — antes solto, agora vive aqui), **Recarregar Lista**,
  **Limpar Cache** (apaga `playlist_*.m3u`), **Sobre o App** e **Sair da Conta**.
  Rodapé mostra usuário IPTV, vencimento, **Endereço MAC** do dispositivo e a
  versão do app.
- **Nova `MoviesScreen.qml` (Filmes) e `SeriesScreen.qml` (Séries)**, ambas
  sobre o componente reutilizável **`VodBrowser.qml`**:
  - Barra de topo (`TopNav`) com abas Home / TV ao Vivo / Filmes / Séries +
    busca.
  - Coluna de **categorias** à esquerda (group-titles dos itens VOD, com
    contagem).
  - **Grade de pôsteres** à direita (capa via `tvg-logo`, com ícone de
    placeholder quando não há capa).
  - Clicar num pôster abre um **player inline** (overlay) sobre a grade; o
    botão Voltar / ESC retorna à grade.
- **Backend (`ChannelManager`)**: novos modelos `moviesModel`/`seriesModel`
  (filtrados por tipo "movie"/"series") e `movieCategoriesModel`/
  `seriesCategoriesModel` (categorias com contagem). Reaproveitam o mesmo
  `QVector` de canais (implicitly shared — sem duplicar dados na memória).
  Novo `clearCache()` para apagar a lista salva em disco.
- **`AppController`**: nova propriedade `appVersion` e método `macAddress()`
  (1ª interface de rede física ativa, via `QNetworkInterface`).
- **Navegação**: Home liga Filmes → `movies`, Séries → `series`,
  Configurações → `settings`. As abas do `TopNav` levam entre TV ao Vivo /
  Filmes / Séries / Home.
- **Sem emoji** (regra do projeto): o ícone de lupa da busca (`TopNav`) deixou
  de ser o emoji 🔍 e virou um SVG (Material Icons). Novos ícones SVG: `back`,
  `dns`, `pulse`, `trash`, `info`, `search`.
- **Player mpv intocado**: nenhuma mudança em qualidade/hwdec/cache/tuning.
  Filmes/Séries reaproveitam o mesmo `StreamPlayer`.

## v1.20 - 2026-05-28
**Redesign Fase 3: TV ao Vivo** — tela refeita no layout de 3 colunas do
modelo TV DIG+.

### App Windows — `app/`
- **Nova `LiveTV.qml`** (substitui `MainPlayer.qml`) com 3 colunas:
  - **Barra de topo** (`TopNav.qml`, reutilizável): abas Home / TV ao Vivo /
    Filmes / Séries + campo de busca + logo TV DIG+ à direita.
  - **Coluna 1 — Categorias** (`CategorySidebar.qml`, reutilizável):
    `group-title` dos canais ao vivo, cada um com a contagem de canais.
  - **Coluna 2 — Canais**: canais da categoria selecionada (número + logo +
    nome). Clique reproduz; duplo-clique reproduz + tela cheia.
  - **Coluna 3 — Player + EPG + botões**: vídeo mpv, nome do canal, lista de
    programas (atual em amarelo + próximos) e botões Playback / Adicionar aos
    Favoritos / Procurar.
- **Lista de TV ao Vivo agora mostra apenas canais ao vivo**: o parser
  classifica cada item por tipo (live/movie/series) pela URL (`/movie/`,
  `/series/`), e a TV ao Vivo filtra só os `live` (~2 mil em vez de ~147 mil).
- **EPG**: novo método `upcoming()` lista o programa atual + os próximos.
- **Botões**: "Favoritos" alterna o canal atual; "Procurar" foca a busca;
  "Playback" fica como "em construção" (a definir).
- **Player mpv intocado**: sem mudanças em qualidade/hwdec/cache/tuning.

### Próximas fases
- v1.21: SettingsScreen com Trocar DNS + Diagnóstico de Rede embutidos
- v1.22: Tela de Filmes (VOD via API Xtream)
- v1.23: Tela de Séries

## v1.19 - 2026-05-28
**Redesign Fase 2: HomeScreen** — hub central após o login.

### App Windows — `app/`
- **Logo do Login reduzida**: 260 → 180 px de largura (a pedido).
- **Nova `HomeScreen.qml`**: tela inicial após o login com layout do
  modelo TV DIG+:
  - Logo TV DIG+ no topo (140 px)
  - Card grande "TV ao Vivo" à esquerda
  - 2 colunas centrais com 4 cards: Filmes, Séries, Conta, Servidores
  - Coluna direita com 3 botões-pílula: Configurações, Recarregar, Sair
  - Vencimento da conta no rodapé (vem do `auth.expiresAt`)
- **Ícones SVG** criados a partir do Material Icons (sem emoji, conforme
  pedido): `tv`, `movie`, `series`, `settings`, `refresh`, `logout`,
  `account`, `servers`. Cor amarela `#FFC107` embutida.
- **Navegação atualizada**: após o login (e após o setup de DNS) o app
  vai para `home`, não mais direto para `player`.
- **Botão "Sair" do MainPlayer agora é "Voltar"**: volta pra Home em vez
  de fazer logout. O logout só fica disponível na HomeScreen (mais
  intuitivo — Home é onde se "sai do app").

### Próximas fases
- v1.20: TV ao Vivo refeita (3 colunas + EPG + botões Playback/Favoritos/Procurar)
- v1.21: SettingsScreen com Trocar DNS + Diagnóstico de Rede embutidos
- v1.22: Tela de Filmes (VOD do M3U)
- v1.23: Tela de Séries

## v1.18 - 2026-05-28
**Início do redesign visual TV DIG+** — Fase 1: tema + login.

### App Windows — `app/`
- **Nova paleta de cores** (`Theme.qml`): preto puro (`#0a0a0a`) com
  amarelo dourado (`#FFC107`) como cor de marca, substituindo o
  azul/roxo `#6366f1` anterior. Cinzas neutros (`#1a1a1a`, `#252525`)
  para cards e bordas. Adicionados `brand2` (hover), `brandSoft`,
  `buttonText` (preto pra contraste em botões amarelos), `textDim`.
- **Logo TV DIG+** (`resources/logos/logo-tvdig.png` e
  `logo-tvdig-square.png`) fornecida pelo usuário, agora embutida via
  resource Qt.
- **Pattern hexagonal sutil** no fundo de todas as telas
  (`resources/patterns/hexagons.svg`, tile-able, opacidade ~4% via
  stroke amarelo). Carregado uma vez no `Main.qml` com `fillMode=Tile`.
- **`LoginScreen.qml` redesenhada**: logo TV DIG+ centralizada,
  campos com cantos arredondados de 12px, foco amarelo nas bordas,
  checkbox com check via Canvas (sem emoji), botão Entrar amarelo
  com texto preto. Layout enxuto, 380px de largura.

### Próximas fases do redesign (planejadas)
- v1.19: HomeScreen — hub central com cards (TV ao Vivo, Filmes, Séries, Configurações…)
- v1.20: TV ao Vivo refeita em 3 colunas (categorias / canais / player+EPG)
- v1.21: SettingsScreen com grid de opções (move Diagnóstico pra cá)
- v1.22: Tela de Filmes (parse VOD do M3U + grid de pôsteres)
- v1.23: Tela de Séries (parse séries + grid + episódios)

## v1.17 - 2026-05-27
"Carregando…" eterno em URLs que retornam erro HTTP.

### Diagnóstico (mpv.log do usuário)
- O usuário tentou abrir um VOD (`.../movie/.../11067.mp4`) e o servidor
  IPTV respondeu **HTTP 406 Not Acceptable** (provavelmente limite de
  sessão simultânea — havia um canal ao vivo ainda drenando o cache).
- mpv tentava fallback via yt-dlp (3 s de overhead), depois falhava com
  `reason=4` (ERROR). Nosso watchdog tentava reload da mesma URL → mesmo
  406 → após N retries dava up SEM avisar a UI, deixando o "Carregando…"
  pra sempre.

### App Windows — `app/`
- **`mpv ytdl=no`**: desabilita o fallback yt-dlp. Pra URLs IPTV o yt-dlp
  só atrasa o erro em ~3 s e enche o log. Falhas viram explícitas na hora.
- **`StreamPlayer.hasError` Q_PROPERTY**: nova flag setada quando:
  1) `MPV_END_FILE_REASON_ERROR` (reason=4) recebido; OU
  2) watchdog esgotou retries em EOF/buffer underrun.
  É resetada automaticamente quando o usuário clica num canal novo.
- **QML mostra "⚠ Canal indisponível"** em vez de "Carregando…" quando
  `player.hasError === true`. Com sub-texto "O servidor recusou a
  conexão. Tente outro canal."

## v1.16 - 2026-05-27
Auto-hide da sidebar/botões **5s** (era 1 min).

### App Windows — `app/`
- `autoHideTimer.interval`: 60000 → 5000 ms. A barra lateral de canais e
  os botões topo-direito (Diagnóstico/Sair) somem após 5 s sem movimento
  de mouse. Movimento de mouse (inclusive sobre a janela de vídeo, via
  forward de `WM_MOUSEMOVE` da v1.14) traz a UI de volta imediatamente.
- Fullscreen continua ocultando permanentemente — mexer o mouse não
  reaparece (intencional: tela cheia é tela cheia).

## v1.15 - 2026-05-27
"DIGTV+ (Não está respondendo)" ao clicar no X pra fechar.

### Diagnóstico
- `mpv_terminate_destroy()` é bloqueante — espera demuxer, decoder e threads
  de rede do mpv finalizarem. Com cache de 60s + conexões HTTP ativas, leva
  vários segundos. Quando chamado no destrutor durante o fechamento, a thread
  da UI fica congelada esperando, e o Windows mostra "Não está respondendo".

### App Windows — `app/`
- **`MpvObject::teardownMpv` move o `mpv_terminate_destroy` para uma thread
  detached.** A UI fecha imediatamente; o cleanup do mpv termina sozinho
  em background. Se o processo for morto pelo OS antes do mpv terminar, os
  recursos são liberados pelo OS de qualquer forma (sockets, threads, etc.).

## v1.14 - 2026-05-27
**Refactor da janela filha do vídeo: QWindow → Win32 nativo puro.**
Resolve 3 bugs num único refactor.

### Diagnóstico (via mpv.log do usuário)
- **Flash branco DEPOIS do preto inicial**: a classe interna do Qt para
  `QWindow` tem `hbrBackground = COLOR_WINDOW` (≈ branco). O Windows
  pinta com esse brush **antes** do `WM_ERASEBKGND` chegar ao
  `nativeEvent` do `BlackBackedWindow` (v1.12), causando o flash.
- **Sidebar não volta ao mover mouse após auto-hide**: `QWindow` filho
  consome `WM_MOUSEMOVE` sem repassar pro QQuickItem pai. O
  `HoverHandler` da QML nunca dispara quando o mouse está sobre o vídeo
  (que cobre quase toda a janela), e o `autoHideTimer` nunca é resetado.
- **"Carregando" no meio do canal**: a v1.13 reload em EOF está funcionando
  (15 ms entre EOF event e novo `loadfile`), mas o cache de 60s segura
  o stream por ~38s depois do disconnect real, então o EOF demora a
  borbulhar. O watchdog de 12s era lento demais pra cobrir esse caso.

### App Windows — `app/`
- **Substitui `QWindow` por classe Win32 nativa custom** (`DIGTVPlusVideoWindow`):
  - `hbrBackground = BLACK_BRUSH` (acaba flash branco — fica preto desde o
    primeiro instante).
  - `WindowProc` próprio com `CS_DBLCLKS`, encaminhando `WM_MOUSEMOVE` →
    signal `MpvObject::userActivity` (QML chama `showUI()` → sidebar volta),
    `WM_LBUTTONDBLCLK` → signal `videoDoubleClicked` (toggle fullscreen).
  - `CreateWindowExW` direto com `WS_CHILD | WS_CLIPSIBLINGS` como filho
    do HWND do `QQuickWindow`. Geometria sincronizada via `SetWindowPos`.
- **mpv `input-default-bindings=no` / `input-vo-keyboard=no` / `input-cursor=no`**:
  garante que mpv não interfira com eventos de input — todos sobem pro
  WindowProc nosso ou pra Qt.
- **Watchdog 12s → 6s** no `StreamPlayer`: stalls não-EOF (buffer underrun
  sem EOF formal) recuperam mais rápido.

### Não alterado a pedido
Qualidade de imagem mantida (`hwdec=auto-safe`, defaults do mpv, sem
`profile=gpu-hq`). Buffers de cache mantidos (60s).

## v1.13 - 2026-05-27
Reduz drasticamente o "Carregando…" no meio do canal.

### App Windows — `app/`
- **Auto-reload imediato em EOF natural**. Stream IPTV ao vivo recebe
  `MPV_END_FILE_REASON_EOF` (reason=0) periodicamente quando Cloudflare/CDN
  corta conexões longas. Antes, o app esperava o watchdog de 12 s pra
  reagir; agora `StreamPlayer` conecta no signal `endFile` do `MpvObject`
  e dispara `loadfile … replace` imediatamente quando reason=0.
  Resultado: gap de "Carregando" no meio do canal cai de 12+ s para ~1-2 s.
- Limite de 5 reloads automáticos por canal (era 3 só no watchdog).
- Outros reasons (`STOP`, `QUIT`, `ERROR`) seguem o fluxo normal — sem
  retry em loop quando a URL retorna 404, por exemplo.

> **Qualidade de imagem** intacta nesta versão (`framedrop=vo`,
> `hwdec=auto-safe`, defaults do mpv) — não mexido a pedido do usuário.

## v1.12 - 2026-05-27
Polimento pós-migração D3D11 da v1.11.

### App Windows — `app/`
- **Fim do flash branco** antes do vídeo aparecer. A janela filha Win32
  herdava `hbrBackground = WHITE_BRUSH` da classe default e, entre o
  momento em que ela é mostrada e o mpv apresentar o primeiro frame D3D11
  (~1 segundo), o Windows pintava tudo de branco. Adicionada a classe
  `BlackBackedWindow : QWindow` que intercepta `WM_ERASEBKGND` via
  `nativeEvent()` e pinta a área cliente de preto. O usuário agora
  vê preto durante o load em vez do flash branco.
- **`surfaceType` da janela filha mudado de `OpenGLSurface` para
  `RasterSurface`**. A v1.11 setava OpenGL por engano — irrelevante já
  que o mpv cria sua própria swapchain D3D11 na HWND. Raster é mais
  leve, sem inicializar contexto OpenGL que não usamos.

## v1.11 - 2026-05-27
**Refactor grande:** player de vídeo agora roda em janela nativa Win32
filha com renderização D3D11 direta — mesma técnica do ProgDVB. Elimina
o overhead de OpenGL FBO + composição Qt das versões anteriores.

### App Windows — `app/`
- **MpvObject deixa de herdar `QQuickFramebufferObject`** (OpenGL-only)
  e passa a herdar `QQuickItem`. Em vez de pintar dentro do scene graph
  do Qt Quick, ele cria uma **janela filha Win32** (`QWindow` com estilo
  `WS_CHILD`) e a posiciona/redimensiona conforme o item se move no
  layout (sidebar abrindo/fechando, fullscreen, etc.).
- **mpv configurado com `vo=gpu` + `gpu-api=d3d11`** e a opção `wid`
  apontando para o HWND da janela filha. Resultado: decodificação DXVA +
  apresentação D3D11 diretamente na janela, sem passar por OpenGL, sem
  cópias entre APIs.
- **Qt Quick backend mudado para `Direct3D11`** (era `OpenGL`). UI e
  vídeo agora compartilham o pipeline nativo Windows. Saímos por
  completo do OpenGL.
- **Nova propriedade `playing`** no MpvObject. True só depois que o mpv
  emite `fileLoaded` (primeiro frame chegou). A QML usa isso para
  esconder a janela nativa de vídeo durante o load inicial, deixando o
  "Carregando…" da QML visível por baixo.

### Limitações conhecidas (v1.11)
- **Overlay sobre o vídeo desaparece**. A janela nativa de vídeo é
  opaca por natureza Win32 — QML pintado por cima é coberto pelo HWND.
  O nome do canal + controles (play/pause/volume/fullscreen) ainda
  existem no código mas não aparecem sobre o vídeo. Solução futura
  (v1.12) é mover esses elementos para a sidebar OU reintroduzir o
  overlay via janela Qt translúcida sobreposta.
- Atalhos de teclado (F11, ESC, setas, números) ainda funcionam por
  ficarem no QQuickItem raiz da tela.

## v1.10 - 2026-05-27
Reverte `profile=gpu-hq` e adiciona framedrop pra eliminar trava-e-volta
em GPUs integradas.

### Diagnóstico (via mpv.log do usuário)
- `GL_RENDERER='Intel(R) HD Graphics 620'` — chip integrado modesto.
- Warnings recorrentes `mpv_render_context_render() not being called or stuck`:
  mpv tinha frames prontos, mas o pipeline OpenGL não conseguia despachá-los
  a tempo → vídeo congela visualmente, mas a internet/decoder estão OK.

### App Windows — `app/`
- **Removido `profile=gpu-hq`** da v1.9. Em GPUs integradas (Intel HD 620,
  UHD 620, AMD Vega 3 etc.), os filtros (`spline36`, sigmoid, deband)
  saturavam o shader pipeline e provocavam o "trava e volta" relatado.
  Defaults do mpv (bilinear) são suficientes pra IPTV.
- **Adicionado `framedrop=vo`**: quando o render atrasa por qualquer
  motivo (GPU lenta, foco mudou, sistema sob carga), mpv agora pula
  frames atrasados em vez de pausar a reprodução até recuperar.
  Visualmente vê micro-stutters em vez de freeze de 1-3 s.

## v1.9 - 2026-05-27
Pacote de polimentos: tela inicial, qualidade de imagem e estabilidade.

### App Windows — `app/`
- **"Carregando…" eterno na tela inicial corrigido**. Aparecia logo após
  o login, antes de qualquer clique. Causa: `MpvObject` mapeava
  `core-idle=true` (mpv sem arquivo) como `m_buffering=true`. No estado
  inicial, `core-idle` fica `true` e o QML achava que estava buffering
  pra sempre. Fix: o "Carregando…" só aparece se `mpv.buffering` E
  `player.currentId !== ""`. Sem canal selecionado, exibe "Selecione
  um canal" cinza no centro.

- **Buffer dobrado pra eliminar travadas momentâneas**. Usuário relatou
  "canal toca e trava, depois volta". É o comportamento de buffer
  underrun: quando o cache esvazia, mpv freezeia no último frame até
  chegar mais dados. Aumentado:
  - `cache-secs` 30 → 60
  - `demuxer-readahead-secs` 3 → 5
  - `demuxer-max-bytes` 150 MiB → 300 MiB
  - `demuxer-max-back-bytes` 50 MiB → 100 MiB
  - `audio-buffer` 0.2 s → 1 s
  Início levemente mais lento (~2 s a mais), mas absorve oscilações
  da rede sem freeze visível.

- **Qualidade de imagem melhor com `profile=gpu-hq`**. Aplica o conjunto
  curado pelo mpv: scaler `spline36`, dithering, sigmoid upscaling,
  deband. Notavelmente mais nítido para streams IPTV 720p/1080p que
  precisam ser upscaled para resoluções de tela maiores. Custa um pouco
  mais de GPU mas a maioria das placas integradas modernas dá conta.

- **Remoção de `audio-buffer` duplicado**: estava sendo setado para
  0.2 s mais abaixo, sobrescrevendo o 1 s. Agora unificado.

## v1.8 - 2026-05-27
Ajustes de UX e estabilidade de longo prazo.

### App Windows — `app/`
- **Sem auto-play no login**: ao entrar no app, a lista carrega mas
  nenhum canal começa a tocar — o usuário escolhe. Reverte o
  `Component.onCompleted` da v1.7 que disparava `player.playRow(0)`.
- **Auto-hide da UI em modo janela**: passa 1 minuto sem movimento de
  mouse, a lista lateral e os botões "Diagnóstico/Sair" somem (anim
  suave de 250ms). Qualquer movimento de mouse traz tudo de volta.
  Implementado com `HoverHandler` no root + `Timer` de 60 s.
- **Tela cheia limpa**: em fullscreen, sidebar e botões topo-direito
  ficam permanentemente escondidos. Só o vídeo. O overlay inferior
  (nome do canal, controles) continua aparecendo em movimento do
  mouse e sumindo em 3 s.
- **Watchdog de reconexão**: se o player ficar 12 segundos travado em
  "Carregando..." (estado `paused-for-cache` ou `core-idle` persistente),
  o `StreamPlayer` força um `loadfile … replace` do canal atual para
  reabrir a conexão. Antes, os flags do ffmpeg (`reconnect=1`) às
  vezes não conseguiam recuperar quando o servidor IPTV dropava a
  conexão sem RST. Limite de 3 retries por canal pra não rodar em
  loop em canal morto.

## v1.7 - 2026-05-27
Pacote de polimentos pós-uso real:

### Player
- **HEVC/H.265 mais compatível**: `hwdec` mudou de `auto-safe` para
  `auto-copy`. Faz copy-back GPU→RAM (alguns ms a mais), mas torna a
  decodificação de HEVC funcional em drivers que falhavam silenciosamente
  no caminho zero-copy.
- **Troca de canal sem delay**: `demuxer-readahead-secs` 10 → 3. Mpv
  começa a exibir com 3 s de buffer em vez de 10 s; continua enchendo
  até 30 s em paralelo.
- **Fim do "Carregando..." perpétuo**: `cache-pause=no` e
  `cache-pause-initial=no`. Antes, qualquer queda de cache parava a
  reprodução até a UI reagir; agora o mpv tenta repor em paralelo e
  segue exibindo o último frame em vez de bloquear na tela "Carregando".

### Logout / shutdown
- **Botão "Sair" não trava mais antes de sair**: o destrutor do MpvObject
  agora chama `mpv_abort_async_command` + `stop` antes do
  `mpv_terminate_destroy`. A QML também envia `stop` antes de navegar
  para a tela de login. Ambos eliminam a espera de timeouts de socket
  que segurava a UI por 1–2 s.

### Auto-play do primeiro canal
- **Player abre tocando o canal 0**: além do listener atual `onListReady`,
  agora o `Component.onCompleted` da tela do player também dispara
  `player.playRow(0)` se nada estiver tocando. Cobre o caso "logout
  depois login" (em que a lista já está em cache e `listReady` não
  dispara de novo).

### Instalador
- **Checkbox "Executar DIGTV+ agora" na última página do instalador**:
  usuário não precisa procurar o atalho no menu Iniciar depois do
  setup. Habilitado por padrão. Página de boas-vindas em PT-BR via MUI2.

## v1.6 - 2026-05-27
Clicar em variantes do mesmo canal (SD/HD/FHD/4K) tocava sempre a primeira
ocorrência. Indicador visual de qual canal está tocando estava muito sutil.

### App Windows — `app/`
- **Bug do tvg-id compartilhado entre variantes**: o M3U costuma marcar
  todas as qualidades do mesmo canal (ex.: Globo SP SD/HD/FHD/4K) com o
  mesmo `tvg-id`. O app usava esse tvg-id como ID de linha, então o índice
  `id -> canal` mantinha apenas a última ocorrência e `playById()` tocava
  sempre o mesmo stream, independente de qual variante o usuário clicava.
  - Adicionado campo `tvgId` separado no `Channel`.
  - `Channel.id` agora é sempre único (sufixo numérico: `globo-sp#17`).
  - EPG continua casando pelo `tvg-id` original via novo
    `player.currentTvgId`, então o guia ainda funciona para todas as
    variantes do mesmo canal.
  > **Atenção**: favoritos e histórico salvos com IDs da v1.5 não vão ser
  > reconhecidos. Vai precisar refavoritar uma vez. (Os arquivos ficam em
  > `%APPDATA%\SwiftIPTV\` se quiser conferir.)
- **Indicador "TOCANDO AGORA" no canal atual**: barra lateral mais larga,
  fundo mais destacado, ícone ▶ e legenda "TOCANDO AGORA" abaixo do nome
  no item da lista. Resolve o problema de não saber qual variante (entre
  GB SP FHD, GB SP HD, GB SP 4K…) está realmente sendo reproduzida.

## v1.5 - 2026-05-27
Lista de canais não refletia mudanças feitas no painel do provedor IPTV
(canais removidos/adicionados/reordenados continuavam aparecendo até o
cache de 6h expirar).

### App Windows — `app/`
- **Login explícito força refresh da M3U**: quando o usuário digita
  usuário/senha e entra, a lista é re-baixada do servidor (ignorando o
  cache). Garante que mudanças no painel do provedor (canais novos,
  removidos, reordenados) aparecem na hora.
- **Auto-login (revalidação ao abrir) continua usando cache**: mantém a
  abertura do app rápida quando "lembrar senha" está ativo. O cache
  expira em 6h e o próximo refresh natural pega o estado atualizado.

## v1.4 - 2026-05-27
Streams começavam a tocar e em segundos voltavam para "Carregando…"
(buffer underrun em qualquer micro-corte de rede).

### App Windows — `app/`
- Removido `profile=low-latency` do libmpv. O perfil aplica defaults muito
  agressivos (cache=no, buffers mínimos) pensados para streaming local em
  rede confiável; em streams IPTV via Cloudflare qualquer hiccup de rede
  era suficiente para pausar a reprodução em loop.
- Cache do mpv expandido para um perfil "VLC-like":
  - `cache-secs` 10 → 30 s
  - `demuxer-readahead-secs` 2 → 10 s
  - `demuxer-max-bytes` 32 MiB → 150 MiB
  - novo `demuxer-max-back-bytes=50 MiB`
- Reconexão automática mais agressiva: `reconnect_delay_max=2`,
  `reconnect_at_eof=1`, e `stream-lavf-o` com os mesmos flags do
  `demuxer-lavf-o` para que stream e demuxer compartilhem a política.
- `network-timeout` 5 s → 10 s (a redução para 5 s na v1.3 era pra trocar
  de canal mais rápido, mas estava cortando reconexões válidas em streams
  com latência maior).
- `+discardcorrupt` no `fflags` para descartar pacotes TS quebrados em vez
  de travar o decoder.

## v1.3 - 2026-05-27
Vídeo invertido + travamento entre canais da mesma categoria.

### App Windows — `app/`
- **Corrige vídeo de cabeça para baixo** no player. O `QQuickFramebufferObject`
  do Qt já entrega o FBO com origem no topo (espaço de tela do Qt Quick), e o
  código pedia ao mpv para flippar Y de novo (`flip_y=1`) — resultado: vídeo
  rotacionado verticalmente. Trocado para `flip_y=0`.
- **Troca de canal mais ágil**: removido `mpv stop` redundante antes do
  `loadfile … replace`. O `replace` já interrompe o stream anterior;
  enfileirar um `stop` extra estava deixando o mpv "ocupado" o suficiente
  para ignorar cliques rápidos em outros canais da mesma categoria.
- **`network-timeout` reduzido de 10s para 5s**: streams que não respondem
  agora derrubam a tentativa em metade do tempo, liberando o decoder para
  o próximo clique.

## v1.2 - 2026-05-27
Correções no player libMPV: tela preta + travamento ao trocar canal em
algumas configurações (drivers/GPUs e servidores IPTV atrás de Cloudflare/WAF).

### App Windows — `app/`
- `hwdec` mudou de `d3d11va` (forçado) para `auto-safe`. O d3d11va forçado
  falhava silenciosamente em algumas combinações driver+codec, resultando em
  janela preta sem mensagem de erro. Com `auto-safe`, o mpv escolhe o melhor
  decodificador de hardware disponível e cai para software se o stream/codec
  não puder ser decodificado em HW.
- User-Agent do libMPV trocado de `SwiftIPTV/1.0` para um UA de Chrome real
  (`Mozilla/5.0 ... Chrome/120 ...`). Servidores IPTV atrás de Cloudflare/WAF
  costumam responder 403 / stream vazio para UAs custom, mesmo quando a URL
  retorna OK em testes HTTP simples.
- Log de diagnóstico do libMPV agora é gravado em
  `%APPDATA%\SwiftIPTV\mpv.log` (nível info), permitindo investigar falhas
  de playback sem precisar de debugger.

## v1.1 - 2026-05-27
Primeira versão hospedada em produção (dixg.com.br) e início do rebrand para DIGTV+.

### App Windows — `app/`
- `SWIFTIPTV_API_URL` agora aponta para `https://dixg.com.br/painel/api/auth.php`
  (era um placeholder `https://seudominio.com/...` na v1.0, o que provocava
  "Algoritmo incompatível" na negociação SSL).
- Rebrand visual parcial: título da janela, tela de login e display name
  da `QGuiApplication` exibem **DIGTV+**.
- Instalador NSIS gera atalho/registro com o nome **DIGTV+**
  (o executável continua `SwiftIPTV.exe` por compatibilidade com o CI).

### Painel — `painel/`
- Painel publicado em `https://dixg.com.br/painel/` (Hostinger).
- `APP_NAME` configurado como **DIGTV+ Panel** em produção.
- Novo arquivo `install/schema_hostinger.sql`: schema sem `CREATE DATABASE/USE`
  para importação direta via phpMyAdmin em hospedagens compartilhadas
  (onde o banco é criado pelo painel da hospedagem e o usuário não tem
  permissão de criar bancos novos).

### Docs
- README com URLs reais do repositório `mclsousa/SwiftIPTV`
  (eram placeholders `SEU_USUARIO/SEU_REPO` na v1.0).

## v1.0 - 2026-05-25
Primeira versão.

### Painel (PHP) — `painel/`
- Login do operador (bcrypt, sessão com regeneração de ID, proteção CSRF).
- Dashboard com métricas, gráfico de 7 dias e últimos acessos.
- Gerência de DNS dos servidores (CRUD, ativar/desativar, prioridade por
  drag-and-drop, teste de latência via AJAX).
- Gerência de clientes nos modos `local` e `xtream`.
- Logs de acesso com filtros, paginação e exportação CSV.
- Endpoint `api/auth.php` (JSON, rate limiting, CORS) consumido pelo app.

### App Windows (C++/Qt/QML/libMPV) — `app/`
- Tela de login com auto-login e "lembrar senha" (XOR + base64).
- Otimização de DNS do PC via `netsh` com elevação UAC sob demanda.
- Player libMPV (hwdec d3d11va) com troca rápida de canal e prefetch.
- Lista de canais virtualizada com busca, favoritos e histórico; EPG overlay.
- Diagnóstico de rede completo (latência, velocidade, perda, DNS DoH A/B,
  teste de servidores IPTV, detecção de VPN, relatório, PDF, histórico).
- Modo `--selftest` (smoke test headless usado pelo CI).

### CI/CD — `.github/`
- Build no Windows (Qt 6.5.3 via aqtinstall + libMPV + MSVC), smoke test,
  geração do `SwiftIPTV-Setup.exe` (NSIS) e publicação como artifact.
- Release automático ao criar tag `v*`, com notas vindas deste CHANGELOG.
