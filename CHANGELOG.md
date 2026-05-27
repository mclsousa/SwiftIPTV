# Changelog

Todas as mudanças relevantes do **SwiftIPTV** (painel + app).

> **Convenção (importante):** cada versão começa com um cabeçalho no formato
> `## v<versão> - AAAA-MM-DD`. O GitHub Actions extrai automaticamente o trecho
> entre `## v1.0` e o próximo `## ` e usa como descrição da Release da tag `v1.0`.

## Não lançado
- Anote aqui o que está em desenvolvimento antes de criar a próxima tag.

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
