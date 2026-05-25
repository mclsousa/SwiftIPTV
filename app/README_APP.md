# SwiftIPTV — App Windows nativo

Player IPTV nativo para Windows 10/11 (x64) em **C++20 + Qt 6 (QML) + libMPV**.
Foco absoluto em **velocidade de troca de canal**.

> Backend: este app autentica contra o painel PHP em
> `https://seudominio.com/swiftiptv/api/auth.php` (constante `SWIFTIPTV_API_URL`
> em `src/core/AuthManager.h` — **atualize com sua URL real**).

---

## 1. Decisões de arquitetura (leia antes)

O spec original tinha dois pontos contraditórios; foram resolvidos assim:

- **libMPV faz rede + demux + decode.** Não há demuxer/decoder próprios — isso é
  trabalho do mpv (FFmpeg embutido). Os "6 threads" do spec mapeiam para:
  *Thread UI* (Qt), *threads internas do mpv* (rede/demux/decode + hwdec d3d11va),
  *EPG loader* (`EPGManager`, thread), *logo downloader* (`NetworkThread`, thread)
  e *prefetch* (`PrefetchEngine`, thread). Comunicação só por signals/slots.
- **UI é QML.** Os arquivos `src/ui/*.cpp` são os **backends C++** expostos ao QML
  (controllers/models), não janelas QWidget. `PlayerWidget` = `MpvObject`
  (`QQuickFramebufferObject` com o render API OpenGL do mpv).

A troca de canal rápida usa o mpv com perfil `low-latency`, `cache` curto,
`fflags=+nobuffer`, flush imediato (`stop`) + `loadfile ... replace`, e
pré-aquecimento de conexão dos canais vizinhos (`PrefetchEngine`).

---

## 2. Pré-requisitos

| Item        | Versão / origem |
|-------------|-----------------|
| Qt          | **6.5+** (MSVC 2019/2022 64-bit). Inclua Qt Quick, QML, Network, PrintSupport, Widgets. |
| Compilador  | Visual Studio 2022 (MSVC v143) ou Build Tools |
| CMake       | 3.21+ |
| Ninja       | (recomendado) |
| libMPV      | Arquivos de desenvolvimento para Windows (header `mpv/client.h` + `mpv.lib` + `libmpv-2.dll`) |

### Obtendo a libMPV (Windows)
1. Baixe um build do **libmpv** (ex.: pacotes "shinchiro" do mpv para Windows ou
   `libmpv-dev` via MSYS2: `pacman -S mingw-w64-x86_64-mpv` — porém para MSVC
   prefira um pacote com `.lib`/header).
2. Organize em uma pasta, ex.: `C:\libs\mpv\`:
   ```
   C:\libs\mpv\include\mpv\client.h
   C:\libs\mpv\include\mpv\render_gl.h
   C:\libs\mpv\lib\mpv.lib        (lib de importação)
   C:\libs\mpv\bin\libmpv-2.dll   (runtime)
   ```
   Se você só tem `libmpv-2.dll`, gere a `.lib` a partir do `.def`:
   ```
   dumpbin /exports libmpv-2.dll > mpv.def   (edite p/ formato .def)
   lib /def:mpv.def /out:mpv.lib /machine:x64
   ```

---

## 3. Configurar e compilar

```bat
cd app
cmake -S . -B build -G "Ninja" ^
      -DCMAKE_PREFIX_PATH="C:/Qt/6.5.3/msvc2019_64" ^
      -DMPV_ROOT="C:/libs/mpv" ^
      -DCMAKE_BUILD_TYPE=Release

cmake --build build --config Release
```

Coloque a DLL do mpv ao lado do executável e rode o deploy do Qt:
```bat
copy C:\libs\mpv\bin\libmpv-2.dll build\
C:\Qt\6.5.3\msvc2019_64\bin\windeployqt.exe --qmldir qml build\SwiftIPTV.exe
build\SwiftIPTV.exe
```

> **Importante:** o app força o backend RHI **OpenGL** (necessário para o interop
> do mpv). Isso é feito em `main.cpp` via `QQuickWindow::setGraphicsApi(OpenGL)`.

---

## 4. Atualizar a URL da API

Edite `src/core/AuthManager.h`:
```cpp
#define SWIFTIPTV_API_URL "https://SEU_DOMINIO/swiftiptv/api/auth.php"
```

---

## 5. Onde ficam os dados

`%APPDATA%\SwiftIPTV\`
```
config.ini            preferências (auth, dns_pc, player, app)
logos\                cache de logos dos canais
cache\                cache da lista M3U (invalidação por MD5)
favorites.json        favoritos
history.json          histórico de canais
diagnosticos.json     últimos 10 diagnósticos
```

---

## 6. Telas / atalhos

| Tela | Descrição |
|------|-----------|
| Login | usuário/senha, "lembrar" (XOR+base64 no config.ini), auto-login na abertura, link de diagnóstico |
| Otimizar DNS | Cloudflare/Google/Quad9/AdGuard/Manter; aplica via `netsh` com elevação UAC sob demanda; salva DNS anterior |
| Player | lista virtualizada com busca, abas Canais/Favoritos/Histórico, EPG overlay, controles |
| Diagnóstico | health score, IP/geo/rede, latência, velocidade, perda, DNS A/B (DoH), servidores IPTV, VPN, relatório (copiar/PDF), histórico |

**Atalhos:** `F11` ou duplo-clique = tela cheia · `↑/←` canal anterior ·
`↓/→` próximo canal · dígitos + `Enter` = ir para o número do canal · `Esc` = sair da tela cheia.

---

## 7. Metas de performance (alvo do design)

| Métrica | Alvo | Como é perseguido |
|---------|------|-------------------|
| Troca UDP | < 300 ms | flush imediato + `nobuffer` + prefetch de vizinhos |
| Troca HLS | < 1.5 s | cache curto + reconnect |
| Lista 10k | < 500 ms | parser em thread + `unordered_map`/`QHash` O(1) + `ListView` virtualizado |
| CPU em reprodução | < 5 % | `hwdec=d3d11va` (decode em GPU) |

> Estes números dependem de rede/servidor/hardware. O código aplica as escolhas
> de design citadas, mas o app **não foi compilado/medido neste ambiente**
> (sem toolchain Qt/MSVC/mpv) — valide localmente após o build.

---

## 8. Limitações conhecidas / simplificações honestas

- **Grupos colapsáveis:** a lista usa cabeçalhos de seção fixos (sticky), não
  colapso por clique — colapso real + virtualização exigiria um modelo de árvore.
- **Restaurar DNS ao sair:** o DNS anterior é salvo no `config.ini`; a restauração
  (`DnsChanger::restoreDns`) também eleva via UAC. A elevação assume o **mesmo
  usuário** (consent UAC); com "outro administrador" o `%APPDATA%` difere.
- **Prefetch** aquece conexão/CDN dos vizinhos (primeiros KB), sem decodificar
  vídeo — escolha proposital para manter a CPU baixa.
- **EPG** assume endpoint Xtream `xmltv.php`. Sem ele, o overlay mostra só o nome.
- O instalador NSIS sai via `cpack -G NSIS` (requer NSIS instalado).
