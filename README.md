# SwiftIPTV

Solução completa de IPTV para operadores: um **painel web** (PHP) para gerenciar
clientes, servidores DNS e logs, e um **app Windows nativo** (C++/Qt/QML + libMPV)
para os clientes assistirem, com troca de canal ultrarrápida e diagnóstico de rede.

> Repositório: **github.com/mclsousa/SwiftIPTV**

[![Build](https://github.com/mclsousa/SwiftIPTV/actions/workflows/build.yml/badge.svg)](https://github.com/mclsousa/SwiftIPTV/actions/workflows/build.yml)

---

## 📦 O que é

| Componente | Pasta | Descrição |
|------------|-------|-----------|
| **Painel** | `painel/` | App web em PHP 8.2 + MySQL. Login do operador, dashboard, DNS, clientes (local/Xtream), logs e a API `api/auth.php` usada pelo app. |
| **App Windows** | `app/` | Player nativo C++20 + Qt 6 (QML) + libMPV. Login, otimização de DNS, player, lista de canais e diagnóstico de rede. |
| **CI/CD** | `.github/` | Build no Windows, smoke test, instalador NSIS e release automático por tag. |

O app autentica contra o painel (`/swiftiptv/api/auth.php`), recebe os
`server_dns` ativos e monta a URL da lista automaticamente.

---

## 🗂 Estrutura do repositório

```
SwiftIPTV/                      <- raiz do repositório
├── .github/workflows/build.yml # CI: build + smoke test + release
├── CHANGELOG.md                # notas de cada versão (alimentam a Release)
├── README.md                   # este arquivo
├── app/                        # app Windows (C++/Qt/QML/libMPV)
│   ├── CMakeLists.txt
│   ├── install.bat             # instala toolchain + compila + gera setup.exe
│   ├── run_smoke_test.bat      # roda o app com a lista de teste
│   ├── installer.nsi           # script do instalador NSIS
│   ├── smoke_test.m3u          # 3 canais de teste
│   ├── src/  qml/  resources/
│   └── README_APP.md           # detalhes de build do app
└── painel/                     # painel web PHP
    ├── config.php  index.php  login.php  ...
    ├── api/auth.php
    ├── install/schema.sql  install/install.php
    └── README_PAINEL.md        # detalhes de instalação do painel
```

---

## 🛠 Como compilar o app Windows

**Pré-requisitos:** Windows 10/11 x64, Visual Studio 2022 (C++), Qt 6.5+, CMake, libMPV.

### Opção A — automática (recomendada)
```bat
cd app
install.bat
```
O script verifica/instala o que falta, compila em Release, roda o `windeployqt`,
copia a `libmpv-2.dll` e gera o `SwiftIPTV-Setup.exe`. Detalhes e solução de
problemas em [`app/README_APP.md`](app/README_APP.md).

### Opção B — manual
```bat
cd app
cmake -S . -B build -G "Visual Studio 17 2022" -A x64 ^
      -DCMAKE_PREFIX_PATH="C:/Qt/6.5.3/msvc2019_64" -DMPV_ROOT="C:/libs/mpv"
cmake --build build --config Release
"C:/Qt/6.5.3/msvc2019_64/bin/windeployqt.exe" --release --qmldir qml build/Release/SwiftIPTV.exe
```

### Testar rápido (sem conta real)
```bat
cd app
run_smoke_test.bat
```
Abre o app já no player com 3 streams de teste (`smoke_test.m3u`).

---

## 🌐 Como fazer deploy do painel

Resumo (passo a passo completo em [`painel/README_PAINEL.md`](painel/README_PAINEL.md)):

1. Copie a pasta `painel/` para a raiz pública do servidor (Apache/Nginx + PHP 8.2).
2. Crie o banco e importe o schema:
   ```bash
   mysql -u root -p < painel/install/schema.sql
   ```
3. Edite `painel/config.php` (DB, `AUTH_MODE`, `SECRET_KEY`, `API_ALLOWED_ORIGIN`).
4. Acesse uma vez `install/install.php` para garantir o operador `admin / admin123`
   (e **apague** esse arquivo depois).
5. Acesse `https://SEU_DOMINIO/swiftiptv/login.php`.
6. No app, confirme que `SWIFTIPTV_API_URL` (em `app/src/core/AuthManager.h`)
   aponta para `https://SEU_DOMINIO/swiftiptv/api/auth.php`.

> Em produção: troque `SECRET_KEY`, defina `APP_DEBUG=false`, use HTTPS e
> restrinja `API_ALLOWED_ORIGIN`.

---

## 🚀 Como criar uma nova release

O build e a publicação são automáticos ao empurrar uma **tag `v*`**.

1. Anote as mudanças no `CHANGELOG.md` em um cabeçalho `## v1.0 - AAAA-MM-DD`.
2. Crie e empurre a tag:
   ```bash
   git add CHANGELOG.md
   git commit -m "Release v1.0"
   git tag v1.0
   git push origin main --tags
   ```
3. O GitHub Actions então:
   - compila o app e gera o `SwiftIPTV-Setup.exe`;
   - cria a **Release `v1.0`** com a descrição vinda da seção `## v1.0` do CHANGELOG;
   - anexa o instalador à Release.

### Links fixos de download
- Última versão (sempre aponta para a mais recente):
  `https://github.com/mclsousa/SwiftIPTV/releases/latest/download/SwiftIPTV-Setup.exe`
- Versão específica:
  `https://github.com/mclsousa/SwiftIPTV/releases/download/v1.0/SwiftIPTV-Setup.exe`

---

## ⚙️ Primeira configuração do repositório

O projeto ainda não é um repositório Git. Para ativar o CI:

```bash
cd "C:/Projetos de Marciel/SwiftIPTV"
git init
git add .
git commit -m "SwiftIPTV: painel + app + CI"
git branch -M main
git remote add origin https://github.com/mclsousa/SwiftIPTV.git
git push -u origin main
```

A partir daí, todo push em `main` roda o build/smoke test, e cada tag `v*`
publica uma Release com o instalador.
