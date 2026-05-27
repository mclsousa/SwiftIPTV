# Changelog

Todas as mudanças relevantes do **SwiftIPTV** (painel + app).

> **Convenção (importante):** cada versão começa com um cabeçalho no formato
> `## v<versão> - AAAA-MM-DD`. O GitHub Actions extrai automaticamente o trecho
> entre `## v1.0` e o próximo `## ` e usa como descrição da Release da tag `v1.0`.

## Não lançado
- Anote aqui o que está em desenvolvimento antes de criar a próxima tag.

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
