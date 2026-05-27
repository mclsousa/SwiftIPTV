# Changelog

Todas as mudanças relevantes do **SwiftIPTV** (painel + app).

> **Convenção (importante):** cada versão começa com um cabeçalho no formato
> `## v<versão> - AAAA-MM-DD`. O GitHub Actions extrai automaticamente o trecho
> entre `## v1.0` e o próximo `## ` e usa como descrição da Release da tag `v1.0`.

## Não lançado
- Anote aqui o que está em desenvolvimento antes de criar a próxima tag.

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
