# TV ao Vivo (3 colunas) — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconstruir a tela "TV ao Vivo" do DIGTV+ no layout de 3 colunas dos modelos do cliente (categorias / canais / player+EPG+botões) com barra de topo, mostrando **apenas canais ao vivo**.

**Architecture:** Mantém a fonte M3U e o player mpv validado. Adiciona classificação de tipo (live/movie/series) por URL no parser, filtros de tipo+categoria no modelo de lista, um modelo de categorias ao vivo, e a lista de programas futuros no EPG. A UI vira 3 componentes QML (TopNav, CategorySidebar, LiveTV) reutilizáveis pelas próximas telas.

**Tech Stack:** C++20, Qt 6.5 (Core/Qml/Quick/Network), QML, libmpv (intocado), CMake, CI no GitHub Actions (Windows).

**Regras invioláveis:** NÃO tocar em `StreamPlayer`, `PlayerWidget`, opções/tuning do mpv, hwdec, cache de qualidade. (Pedido explícito do cliente.)

**Verificação (contexto do projeto):** Não há test runner. "Verificar build" = compilar com a toolchain do CI localmente **ou** empurrar numa branch para o GitHub Actions compilar (`gh run watch`). "Verificar runtime" = o cliente instala o release e confere contra o modelo. Cada tarefa diz o que esperar.

---

## Estrutura de arquivos

**C++ (modificar):**
- `app/src/core/M3UParser.h` — campo `Channel.type`.
- `app/src/core/M3UParser.cpp` — classificação por URL.
- `app/src/ui/ChannelList.h` / `.cpp` — `ChannelListModel` ganha `typeFilter`+`categoryFilter`+`TypeRole`; novo `CategoryListModel`.
- `app/src/core/ChannelManager.h` / `.cpp` — expõe `liveCategoriesModel`; `m_model` filtra `live`; constrói categorias.
- `app/src/core/EPGManager.h` / `.cpp` — `upcoming(channelId, n)`.

**QML (criar):**
- `app/qml/TopNav.qml` — barra de topo (abas + busca + logo).
- `app/qml/CategorySidebar.qml` — coluna de categorias.
- `app/qml/LiveTV.qml` — a tela TV ao Vivo (3 colunas), assume o papel de `"player"`.

**QML/Build (modificar):**
- `app/qml/Main.qml` — `case "player"` carrega `LiveTV.qml`.
- `app/CMakeLists.txt` — registra os 3 novos QML, remove `MainPlayer.qml`.

**QML (remover):**
- `app/qml/MainPlayer.qml` — substituído por `LiveTV.qml`.

---

## Task 1: Campo `Channel.type` + classificação no parser

**Files:**
- Modify: `app/src/core/M3UParser.h`
- Modify: `app/src/core/M3UParser.cpp:77-88`

- [ ] **Step 1: Adicionar o campo `type` ao struct `Channel`**

Em `app/src/core/M3UParser.h`, dentro do struct `Channel`, depois de `QString url;`:

```cpp
    QString url;    // URL do stream
    QString type;   // "live" | "movie" | "series" — classificado pela URL do stream.
    int     number = 0;
```

- [ ] **Step 2: Classificar o tipo ao fechar cada canal**

Em `app/src/core/M3UParser.cpp`, no bloco `else if (haveExtinf)` (onde `cur.url` é definido), logo após `cur.url = svline.toString().trimmed();`:

```cpp
        } else if (haveExtinf) {
            cur.url = svline.toString().trimmed();
            // Xtream Codes: /movie/ e /series/ no caminho separam VOD/séries dos
            // canais ao vivo (que não têm prefixo de tipo na URL).
            if (cur.url.contains(QStringLiteral("/movie/")))       cur.type = QStringLiteral("movie");
            else if (cur.url.contains(QStringLiteral("/series/"))) cur.type = QStringLiteral("series");
            else                                                   cur.type = QStringLiteral("live");
            cur.number = ++counter;
```

(O restante do bloco permanece igual.)

- [ ] **Step 3: Verificar build**

Compilar o projeto (CI ou local). Esperado: compila sem erros (o campo novo não quebra nada; `Channel` continua sendo POD copiável).

- [ ] **Step 4: Commit**

```bash
git add app/src/core/M3UParser.h app/src/core/M3UParser.cpp
git commit -m "feat(parser): classifica canal por tipo (live/movie/series) via URL"
```

---

## Task 2: `ChannelListModel` com filtro de tipo e categoria

**Files:**
- Modify: `app/src/ui/ChannelList.h`
- Modify: `app/src/ui/ChannelList.cpp`

- [ ] **Step 1: Declarar roles, propriedades e membros novos**

Em `app/src/ui/ChannelList.h`, no `enum Roles` adicionar `TypeRole`:

```cpp
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole, LogoUrlRole, LogoLocalRole, GroupRole, UrlRole, NumberRole, CurrentRole, TypeRole
    };
```

Adicionar as `Q_PROPERTY` logo após a de `filter`:

```cpp
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(QString typeFilter READ typeFilter WRITE setTypeFilter NOTIFY typeFilterChanged)
    Q_PROPERTY(QString categoryFilter READ categoryFilter WRITE setCategoryFilter NOTIFY categoryFilterChanged)
```

Adicionar os getters (perto de `QString filter() const`):

```cpp
    QString filter() const { return m_filter; }
    QString typeFilter() const { return m_typeFilter; }
    QString categoryFilter() const { return m_categoryFilter; }
```

Adicionar os setters em `public slots:` (perto de `void setFilter`):

```cpp
    void setFilter(const QString& text);
    void setTypeFilter(const QString& type);
    void setCategoryFilter(const QString& category);
```

Adicionar os sinais (perto de `void filterChanged();`):

```cpp
    void filterChanged();
    void typeFilterChanged();
    void categoryFilterChanged();
```

Adicionar os membros (perto de `QString m_filter;`):

```cpp
    QString m_filter;
    QString m_typeFilter;
    QString m_categoryFilter;
```

- [ ] **Step 2: Expor o `TypeRole` em `data()` e `roleNames()`**

Em `app/src/ui/ChannelList.cpp`, em `roleNames()` adicionar a entrada:

```cpp
        {NumberRole, "number"}, {CurrentRole, "isCurrent"}, {TypeRole, "type"}
```

Em `data()`, adicionar o case (antes do `case LogoLocalRole:`):

```cpp
        case NumberRole:  return c.number;
        case TypeRole:    return c.type;
        case CurrentRole: return c.id == m_currentId;
```

- [ ] **Step 3: Combinar os filtros em `rebuild()`**

Em `app/src/ui/ChannelList.cpp`, substituir o corpo de `rebuild()` por:

```cpp
void ChannelListModel::rebuild() {
    m_visible.clear();
    m_visible.reserve(m_all.size());
    const QString f = m_filter;
    for (int i = 0; i < m_all.size(); ++i) {
        const Channel& c = m_all[i];
        if (!m_typeFilter.isEmpty()     && c.type  != m_typeFilter)     continue;
        if (!m_categoryFilter.isEmpty() && c.group != m_categoryFilter) continue;
        if (!f.isEmpty() && !c.name.contains(f, Qt::CaseInsensitive))   continue;
        m_visible.push_back(i);
    }
}
```

- [ ] **Step 4: Implementar os setters novos**

Em `app/src/ui/ChannelList.cpp`, logo após `setFilter(...)`:

```cpp
void ChannelListModel::setTypeFilter(const QString& type) {
    if (m_typeFilter == type) return;
    m_typeFilter = type;
    beginResetModel();
    rebuild();
    endResetModel();
    emit typeFilterChanged();
    emit countChanged();
}

void ChannelListModel::setCategoryFilter(const QString& category) {
    if (m_categoryFilter == category) return;
    m_categoryFilter = category;
    beginResetModel();
    rebuild();
    endResetModel();
    emit categoryFilterChanged();
    emit countChanged();
}
```

- [ ] **Step 5: Verificar build**

Compilar. Esperado: compila sem erros. O comportamento padrão não muda (filtros vazios = mostra tudo), então favoritos/histórico seguem iguais.

- [ ] **Step 6: Commit**

```bash
git add app/src/ui/ChannelList.h app/src/ui/ChannelList.cpp
git commit -m "feat(model): ChannelListModel com filtro de tipo e categoria"
```

---

## Task 3: `CategoryListModel` (categorias com contagem)

**Files:**
- Modify: `app/src/ui/ChannelList.h`
- Modify: `app/src/ui/ChannelList.cpp`

- [ ] **Step 1: Declarar a classe `CategoryListModel`**

Em `app/src/ui/ChannelList.h`, ao final do arquivo (após a classe `ChannelListModel`):

```cpp
// Modelo de categorias (group-title distintos) com contagem de canais.
// Usado pela coluna esquerda da tela TV ao Vivo.
class CategoryListModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Roles { NameRole = Qt::UserRole + 1, CountRole };
    explicit CategoryListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_cats.size()); }
    void setCategories(const QVector<QPair<QString,int>>& cats);

signals:
    void countChanged();

private:
    QVector<QPair<QString,int>> m_cats; // (nome, contagem) na ordem de aparição
};
```

- [ ] **Step 2: Implementar `CategoryListModel`**

Em `app/src/ui/ChannelList.cpp`, ao final do arquivo:

```cpp
// ---------------------------------------------------------------------------
// CategoryListModel
// ---------------------------------------------------------------------------
CategoryListModel::CategoryListModel(QObject* parent) : QAbstractListModel(parent) {}

int CategoryListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return int(m_cats.size());
}

QHash<int, QByteArray> CategoryListModel::roleNames() const {
    return { {NameRole, "name"}, {CountRole, "count"} };
}

QVariant CategoryListModel::data(const QModelIndex& index, int role) const {
    const int row = index.row();
    if (row < 0 || row >= m_cats.size()) return {};
    switch (role) {
        case NameRole:  return m_cats[row].first;
        case CountRole: return m_cats[row].second;
    }
    return {};
}

void CategoryListModel::setCategories(const QVector<QPair<QString,int>>& cats) {
    beginResetModel();
    m_cats = cats;
    endResetModel();
    emit countChanged();
}
```

- [ ] **Step 3: Verificar build**

Compilar. Esperado: compila sem erros. (A classe ainda não é usada; só está definida.)

- [ ] **Step 4: Commit**

```bash
git add app/src/ui/ChannelList.h app/src/ui/ChannelList.cpp
git commit -m "feat(model): CategoryListModel para categorias com contagem"
```

---

## Task 4: `ChannelManager` expõe categorias ao vivo

**Files:**
- Modify: `app/src/core/ChannelManager.h`
- Modify: `app/src/core/ChannelManager.cpp`

- [ ] **Step 1: Declarar a propriedade e o membro**

Em `app/src/core/ChannelManager.h`, adicionar o include no topo (perto dos outros):

```cpp
#include "core/M3UParser.h"
```

(já existe — confirmar). Adicionar a forward declaration perto de `class ChannelListModel;`:

```cpp
class ChannelListModel;
class CategoryListModel;
```

Adicionar a `Q_PROPERTY` (perto da de `historyModel`):

```cpp
    Q_PROPERTY(QObject* liveCategoriesModel READ liveCategoriesModel CONSTANT)
```

Adicionar o getter (perto de `QObject* historyModel() const;`):

```cpp
    QObject* liveCategoriesModel() const;
```

Adicionar declaração do helper privado (perto de `void rebuildAuxModels();`):

```cpp
    void rebuildAuxModels();
    void rebuildLiveCategories();
```

Adicionar o membro (perto de `ChannelListModel* m_histModel;`):

```cpp
    ChannelListModel* m_histModel;
    CategoryListModel* m_catModel;
```

- [ ] **Step 2: Inicializar o modelo e fixar o filtro live no modelo principal**

Em `app/src/core/ChannelManager.cpp`, no construtor, após criar os modelos:

```cpp
    m_model     = new ChannelListModel(this);
    m_favModel  = new ChannelListModel(this);
    m_histModel = new ChannelListModel(this);
    m_catModel  = new CategoryListModel(this);
    // A tela TV ao Vivo usa o modelo principal e mostra só canais ao vivo.
    // Favoritos/Histórico (m_favModel/m_histModel) ficam sem typeFilter.
    m_model->setTypeFilter(QStringLiteral("live"));
```

Adicionar o getter (perto de `QObject* ChannelManager::historyModel() const`):

```cpp
QObject* ChannelManager::liveCategoriesModel() const { return m_catModel; }
```

- [ ] **Step 3: Construir as categorias quando a lista parseia**

Em `app/src/core/ChannelManager.cpp`, em `onParsed(...)`, após `rebuildAuxModels();`:

```cpp
void ChannelManager::onParsed(QVector<Channel> channels) {
    m_channels = std::move(channels);
    m_model->setSource(m_channels);
    rebuildAuxModels();
    rebuildLiveCategories();
    setLoading(false);
    setStatus(tr("%1 canais carregados.").arg(m_channels.size()));
    emit listReady(m_channels.size());
}
```

Implementar `rebuildLiveCategories()` logo após `rebuildAuxModels()`:

```cpp
void ChannelManager::rebuildLiveCategories() {
    // Categorias distintas entre canais ao vivo, preservando a ordem de
    // aparição no M3U, com a contagem de canais de cada uma.
    QVector<QPair<QString,int>> cats;
    QHash<QString,int> idx;
    for (const auto& c : m_channels) {
        if (c.type != QStringLiteral("live")) continue;
        auto it = idx.constFind(c.group);
        if (it == idx.constEnd()) { idx.insert(c.group, int(cats.size())); cats.push_back({c.group, 1}); }
        else ++cats[it.value()].second;
    }
    m_catModel->setCategories(cats);
}
```

- [ ] **Step 4: Incluir o header onde necessário**

Em `app/src/core/ChannelManager.cpp`, confirmar que `#include "ui/ChannelList.h"` já está presente no topo (está — linha 5). O `CategoryListModel` vive nesse header, então nenhum include novo é preciso.

- [ ] **Step 5: Verificar build**

Compilar. Esperado: compila sem erros.

- [ ] **Step 6: Verificar runtime (instalar)**

Após o release: a tela atual (ainda 2 colunas até a Task 8) não muda visualmente, mas a lista de canais agora mostra **só ao vivo** (~2.118), não ~147 mil. (Checagem opcional aqui; o teste visual completo é na Task 8.)

- [ ] **Step 7: Commit**

```bash
git add app/src/core/ChannelManager.h app/src/core/ChannelManager.cpp
git commit -m "feat(channels): expoe modelo de categorias ao vivo + filtra lista para live"
```

---

## Task 5: `EPGManager::upcoming` (programas atual + próximos)

**Files:**
- Modify: `app/src/core/EPGManager.h`
- Modify: `app/src/core/EPGManager.cpp`

- [ ] **Step 1: Declarar o método**

Em `app/src/core/EPGManager.h`, adicionar o include no topo:

```cpp
#include <QVariantList>
```

Adicionar em `public slots:` (perto de `QString currentTimes(...)`):

```cpp
    QString currentTimes(const QString& channelId) const;    // "20:00 - 21:00"
    // Lista dos próximos n programas a partir de agora (inclui o atual primeiro).
    // Cada item: { "times": "HH:mm ~ HH:mm", "title": QString, "current": bool }.
    Q_INVOKABLE QVariantList upcoming(const QString& channelId, int n = 4) const;
```

- [ ] **Step 2: Implementar `upcoming`**

Em `app/src/core/EPGManager.cpp`, adicionar o include no topo:

```cpp
#include <QVariantMap>
```

Adicionar a implementação ao final do arquivo:

```cpp
QVariantList EPGManager::upcoming(const QString& channelId, int n) const {
    QVariantList out;
    auto it = m_guide.constFind(channelId);
    if (it == m_guide.constEnd()) return out;
    const QDateTime now = QDateTime::currentDateTime();
    for (const auto& p : it.value()) {
        if (p.stop <= now) continue;            // já terminou: pula
        QVariantMap m;
        m["times"]   = p.start.toString("HH:mm") + " ~ " + p.stop.toString("HH:mm");
        m["title"]   = p.title;
        m["current"] = (p.start <= now && now < p.stop);
        out.push_back(m);
        if (out.size() >= n) break;
    }
    return out;
}
```

- [ ] **Step 3: Verificar build**

Compilar. Esperado: compila sem erros.

- [ ] **Step 4: Commit**

```bash
git add app/src/core/EPGManager.h app/src/core/EPGManager.cpp
git commit -m "feat(epg): metodo upcoming() com programa atual + proximos"
```

---

## Task 6: `TopNav.qml` (barra de topo reutilizável)

**Files:**
- Create: `app/qml/TopNav.qml`

- [ ] **Step 1: Criar o componente**

Criar `app/qml/TopNav.qml`:

```qml
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SwiftIPTV

// Barra de topo do DIGTV+: abas de navegação + busca + logo.
// Reutilizável por TV ao Vivo, Filmes e Séries.
Rectangle {
    id: nav
    height: 64
    color: Theme.bg

    // Aba ativa: "home" | "live" | "movies" | "series"
    property string active: "live"
    // Texto da busca (two-way com a tela hospedeira)
    property alias searchText: searchField.text
    signal tabClicked(string key)
    // Expor o foco da busca para o botão "Procurar"
    function focusSearch() { searchField.forceActiveFocus() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 20
        spacing: 28

        Repeater {
            model: [
                { k: "home",   t: "Home" },
                { k: "live",   t: "TV ao Vivo" },
                { k: "movies", t: "Filmes" },
                { k: "series", t: "Séries" }
            ]
            delegate: Text {
                required property var modelData
                text: modelData.t
                color: nav.active === modelData.k ? Theme.brand : Theme.text
                font.pixelSize: 22
                font.bold: nav.active === modelData.k
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nav.tabClicked(modelData.k)
                }
            }
        }

        // Campo de busca
        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 420
            height: 38
            radius: 19
            color: Theme.panel
            border.color: Theme.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 8
                Text { text: "🔍"; color: Theme.subtext; font.pixelSize: 14 }
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    color: Theme.text
                    placeholderText: ""
                    background: null
                    verticalAlignment: TextInput.AlignVCenter
                }
            }
        }

        Item { Layout.fillWidth: true }

        Image {
            source: "qrc:/qt/qml/SwiftIPTV/resources/logos/logo-tvdig.png"
            sourceSize.height: 34
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // Linha inferior sutil
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
}
```

- [ ] **Step 2: Registrar no CMake (provisório p/ compilar)**

Em `app/CMakeLists.txt`, dentro de `QML_FILES`, adicionar a linha (mantendo `MainPlayer.qml` por enquanto — será removido na Task 9):

```cmake
        qml/MainPlayer.qml
        qml/TopNav.qml
        qml/DiagnosticView.qml
```

- [ ] **Step 3: Verificar build**

Compilar. Esperado: compila e o módulo QML registra `TopNav` sem erros.

- [ ] **Step 4: Commit**

```bash
git add app/qml/TopNav.qml app/CMakeLists.txt
git commit -m "feat(ui): TopNav.qml (abas + busca + logo) reutilizavel"
```

---

## Task 7: `CategorySidebar.qml` (coluna de categorias)

**Files:**
- Create: `app/qml/CategorySidebar.qml`

- [ ] **Step 1: Criar o componente**

Criar `app/qml/CategorySidebar.qml`:

```qml
import QtQuick
import QtQuick.Controls.Basic
import SwiftIPTV

// Coluna de categorias: nome + contagem, item selecionado em amarelo.
// Reutilizável por TV ao Vivo / Filmes / Séries.
Rectangle {
    id: side
    color: Theme.bg

    property var categoryModel: null        // CategoryListModel
    property string current: ""             // categoria selecionada (name)
    signal categorySelected(string name)

    ListView {
        id: lv
        anchors.fill: parent
        clip: true
        model: side.categoryModel
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { }

        delegate: Rectangle {
            id: catRow
            required property string name
            required property int count
            width: ListView.view.width
            height: 56
            color: side.current === name ? Theme.panel2
                   : (catMouse.containsMouse ? Theme.panel : "transparent")

            Rectangle {
                width: 4; height: parent.height
                color: Theme.brand
                visible: side.current === catRow.name
            }
            Text {
                anchors.left: parent.left; anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 70
                text: catRow.name
                color: side.current === catRow.name ? Theme.brand : Theme.text
                font.pixelSize: 15
                font.bold: side.current === catRow.name
                elide: Text.ElideRight
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: catRow.count
                color: Theme.subtext
                font.pixelSize: 14
            }
            MouseArea {
                id: catMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: side.categorySelected(catRow.name)
            }
        }
    }
}
```

- [ ] **Step 2: Registrar no CMake**

Em `app/CMakeLists.txt`, dentro de `QML_FILES`, adicionar após `qml/TopNav.qml`:

```cmake
        qml/TopNav.qml
        qml/CategorySidebar.qml
        qml/DiagnosticView.qml
```

- [ ] **Step 3: Verificar build**

Compilar. Esperado: compila e registra `CategorySidebar` sem erros.

- [ ] **Step 4: Commit**

```bash
git add app/qml/CategorySidebar.qml app/CMakeLists.txt
git commit -m "feat(ui): CategorySidebar.qml (categorias com contagem)"
```

---

## Task 8: `LiveTV.qml` (tela TV ao Vivo, 3 colunas)

**Files:**
- Create: `app/qml/LiveTV.qml`

Esta tela reaproveita o backend de player existente (`player.attach(mpv)`, `MpvPlayer`, `player.playById`, `player.currentName/currentId/currentTvgId/hasError`, `mpv.playing/buffering/...`), a navegação por teclado e o fullscreen do antigo `MainPlayer.qml`, mas no layout de 3 colunas + TopNav.

- [ ] **Step 1: Criar o arquivo com a estrutura base (topo + 3 colunas)**

Criar `app/qml/LiveTV.qml`:

```qml
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

Item {
    id: root
    anchors.fill: parent
    focus: true

    property string currentCategory: ""
    property string numberBuffer: ""

    // Fullscreen: esconde topo + colunas, deixa só o vídeo.
    readonly property bool isFullscreen: Window.window && Window.window.visibility === Window.FullScreen
    function toggleFullscreen() {
        var w = Window.window
        w.visibility = (w.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
    }

    // EPG do canal atual (atual + próximos)
    property var epgList: []
    function refreshEpg() {
        var key = player.currentTvgId ? player.currentTvgId : player.currentId
        epgList = key ? epg.upcoming(key, 5) : []
    }

    // Seleciona a primeira categoria assim que a lista de categorias existir.
    function selectFirstCategoryIfNeeded() {
        if (root.currentCategory === "" && channels.liveCategoriesModel.count > 0) {
            var name = channels.liveCategoriesModel.data(
                channels.liveCategoriesModel.index(0, 0),
                Qt.UserRole + 1)  // NameRole
            if (name) root.setCategory(name)
        }
    }
    function setCategory(name) {
        root.currentCategory = name
        channels.model.categoryFilter = name
    }

    Component.onCompleted: {
        forceActiveFocus()
        channels.model.filter = ""
        selectFirstCategoryIfNeeded()
        refreshEpg()
    }

    Connections {
        target: channels
        function onListReady(n) {
            Window.window.notify(n + " canais carregados")
            selectFirstCategoryIfNeeded()
        }
        function onError(m) { Window.window.notify(m) }
    }
    Connections {
        target: player
        function onCurrentChanged() { refreshEpg() }
    }
    Timer { interval: 15000; running: true; repeat: true; onTriggered: refreshEpg() }

    // -------- Atalhos de teclado (portados do MainPlayer) --------
    Keys.onPressed: function(e) {
        if (e.key === Qt.Key_F11) { toggleFullscreen(); e.accepted = true }
        else if (e.key === Qt.Key_Escape) {
            if (root.isFullscreen) toggleFullscreen(); e.accepted = true
        }
        else if (e.key === Qt.Key_Up)   { player.prev(); e.accepted = true }
        else if (e.key === Qt.Key_Down) { player.next(); e.accepted = true }
        else if (e.key >= Qt.Key_0 && e.key <= Qt.Key_9) {
            numberBuffer += (e.key - Qt.Key_0); numberEntry.visible = true; numberTimer.restart(); e.accepted = true
        }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (numberBuffer.length > 0) { player.playNumber(parseInt(numberBuffer)); numberBuffer=""; numberEntry.visible=false }
            e.accepted = true
        }
    }
    Timer {
        id: numberTimer; interval: 1500
        onTriggered: { if (numberBuffer.length>0) player.playNumber(parseInt(numberBuffer)); numberBuffer=""; numberEntry.visible=false }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- Barra de topo ----------
        TopNav {
            id: topNav
            Layout.fillWidth: true
            visible: !root.isFullscreen
            active: "live"
            onTabClicked: function(key) {
                if (key === "home") { mpv.command(["stop"]); app.navigate("home") }
                else if (key === "movies") Window.window.notify("Filmes (em construção)")
                else if (key === "series") Window.window.notify("Séries (em construção)")
            }
            onSearchTextChanged: channels.model.filter = topNav.searchText
        }

        // ---------- Corpo: 3 colunas ----------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Coluna 1: categorias
            CategorySidebar {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                visible: !root.isFullscreen
                categoryModel: channels.liveCategoriesModel
                current: root.currentCategory
                onCategorySelected: function(name) { root.setCategory(name) }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border; visible: !root.isFullscreen }

            // Coluna 2: canais da categoria
            Rectangle {
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                visible: !root.isFullscreen
                color: Theme.bg

                ListView {
                    id: chList
                    anchors.fill: parent
                    clip: true
                    model: channels.model
                    cacheBuffer: 400
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }

                    delegate: Rectangle {
                        id: chRow
                        required property string channelId
                        required property string name
                        required property int number
                        required property string logoLocal
                        required property bool isCurrent
                        width: ListView.view.width
                        height: 52
                        color: isCurrent ? Theme.panel2 : (chMouse.containsMouse ? Theme.panel : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14; anchors.rightMargin: 12; spacing: 10
                            Text {
                                text: chRow.number
                                color: chRow.isCurrent ? Theme.brand : Theme.subtext
                                font.pixelSize: 13; Layout.preferredWidth: 44
                            }
                            Rectangle {
                                width: 30; height: 30; radius: 5; color: Theme.panel2; clip: true
                                Image {
                                    anchors.fill: parent; fillMode: Image.PreserveAspectFit
                                    asynchronous: true; cache: true
                                    source: chRow.logoLocal ? chRow.logoLocal : ""
                                    visible: source != ""
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: chRow.name
                                color: chRow.isCurrent ? Theme.brand : Theme.text
                                font.pixelSize: 14
                                font.bold: chRow.isCurrent
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            id: chMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: player.playById(chRow.channelId)
                            onDoubleClicked: { player.playById(chRow.channelId); root.toggleFullscreen() }
                        }
                    }
                }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border; visible: !root.isFullscreen }

            // Coluna 3: player + EPG + botões
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.bg

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.isFullscreen ? 0 : 16
                    spacing: 12

                    // Painel de vídeo 16:9
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.isFullscreen ? root.height : width * 9 / 16
                        color: "black"
                        radius: root.isFullscreen ? 0 : 8
                        clip: true

                        MpvPlayer {
                            id: mpv
                            anchors.fill: parent
                            visible: mpv.playing
                            Component.onCompleted: player.attach(mpv)
                            onVideoDoubleClicked: root.toggleFullscreen()
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !player.currentId || player.currentId === ""
                            text: "Selecione um canal"; color: "#a0a8b8"; font.pixelSize: 18
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: mpv.buffering && player.currentId && player.currentId !== "" && !player.hasError
                            text: "Carregando..."; color: "white"; font.pixelSize: 16
                        }
                        Column {
                            anchors.centerIn: parent
                            visible: player.hasError
                            spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: "⚠"; color: "#ffb86b"; font.pixelSize: 36 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: "Canal indisponível"; color: "white"; font.pixelSize: 18; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: "O servidor recusou a conexão. Tente outro canal."
                                color: "#a0a8b8"; font.pixelSize: 13 }
                        }
                        MouseArea {
                            anchors.fill: parent; acceptedButtons: Qt.LeftButton
                            onDoubleClicked: root.toggleFullscreen()
                            onClicked: root.forceActiveFocus()
                        }
                    }

                    // Nome do canal atual
                    Text {
                        Layout.fillWidth: true
                        visible: !root.isFullscreen
                        text: player.currentName ? player.currentName : ""
                        color: Theme.text; font.pixelSize: 22; font.bold: true
                        elide: Text.ElideRight
                    }

                    // Lista de programas (EPG)
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.isFullscreen
                        clip: true
                        model: root.epgList
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { }
                        delegate: RowLayout {
                            required property var modelData
                            width: ListView.view.width
                            height: 34
                            spacing: 14
                            Text {
                                text: modelData.times
                                color: modelData.current ? Theme.brand : Theme.subtext
                                font.pixelSize: 13; font.bold: modelData.current
                                Layout.preferredWidth: 130
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: modelData.current ? Theme.brand : Theme.textDim
                                font.pixelSize: 13; elide: Text.ElideRight
                            }
                        }
                    }

                    // Botões
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        visible: !root.isFullscreen
                        spacing: 12
                        Item { Layout.fillWidth: true }
                        PillButton {
                            label: "Playback"
                            onClicked: Window.window.notify("Playback (em construção)")
                        }
                        PillButton {
                            label: player.currentId && channels.isFavorite(player.currentId)
                                   ? "Remover dos Favoritos" : "Adicionar aos Favoritos"
                            enabled: player.currentId && player.currentId !== ""
                            onClicked: { channels.toggleFavorite(player.currentId); favTick = !favTick }
                        }
                        PillButton {
                            label: "Procurar"
                            onClicked: topNav.focusSearch()
                        }
                    }
                }

                // Entrada numérica de canal (overlay)
                Rectangle {
                    id: numberEntry; visible: false
                    anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 24
                    width: 90; height: 56; radius: 10; color: "#cc000000"; z: 40
                    Text { anchors.centerIn: parent; text: root.numberBuffer; color: "white"; font.pixelSize: 26; font.bold: true }
                }
            }
        }
    }

    // Força reavaliação do rótulo do botão Favoritos ao alternar.
    property bool favTick: false

    // Botão "pílula" amarelo (texto preto), padrão dos modelos.
    component PillButton: Rectangle {
        id: pill
        property string label: ""
        property bool enabled: true
        signal clicked()
        implicitWidth: pillText.implicitWidth + 36
        implicitHeight: 44
        radius: 22
        color: !enabled ? Theme.panel2 : (pillMouse.containsMouse ? Theme.brand2 : Theme.brand)
        opacity: enabled ? 1.0 : 0.5
        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: Theme.buttonText
            font.pixelSize: 14; font.bold: true
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: pill.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (pill.enabled) pill.clicked()
        }
    }
}
```

Nota sobre `favTick`: o rótulo do botão Favoritos lê `channels.isFavorite(...)` (função, não property bindável). `favTick` é alternado no clique e referenciado no binding do label para forçar a reavaliação — ajustar o binding do label para incluir `favTick`:

```qml
                            label: (favTick, player.currentId && channels.isFavorite(player.currentId))
                                   ? "Remover dos Favoritos" : "Adicionar aos Favoritos"
```

- [ ] **Step 2: Verificar build**

Compilar. Esperado: compila e registra o tipo `LiveTV` (ainda não usado pelo `Main.qml` — Task 9). Adicionar provisoriamente ao `QML_FILES` para compilar (será confirmado na Task 9):

```cmake
        qml/CategorySidebar.qml
        qml/LiveTV.qml
        qml/DiagnosticView.qml
```

- [ ] **Step 3: Commit**

```bash
git add app/qml/LiveTV.qml app/CMakeLists.txt
git commit -m "feat(ui): LiveTV.qml - tela TV ao Vivo em 3 colunas"
```

---

## Task 9: Ligar `Main.qml` na nova tela + remover `MainPlayer.qml`

**Files:**
- Modify: `app/qml/Main.qml:42`
- Modify: `app/CMakeLists.txt`
- Delete: `app/qml/MainPlayer.qml`

- [ ] **Step 1: Apontar o loader para `LiveTV.qml`**

Em `app/qml/Main.qml`, no `switch`, trocar o case `"player"`:

```qml
            case "player":     return "LiveTV.qml"
```

- [ ] **Step 2: Remover `MainPlayer.qml` do CMake e do disco**

Em `app/CMakeLists.txt`, remover a linha `qml/MainPlayer.qml` do bloco `QML_FILES`. O bloco final deve listar:

```cmake
        qml/Theme.qml
        qml/Main.qml
        qml/LoginScreen.qml
        qml/DnsSetup.qml
        qml/HomeScreen.qml
        qml/TopNav.qml
        qml/CategorySidebar.qml
        qml/LiveTV.qml
        qml/DiagnosticView.qml
```

Apagar o arquivo:

```bash
git rm app/qml/MainPlayer.qml
```

- [ ] **Step 3: Verificar build**

Compilar. Esperado: compila sem erros e sem referência pendente a `MainPlayer`.

- [ ] **Step 4: Commit**

```bash
git add app/qml/Main.qml app/CMakeLists.txt
git commit -m "feat(ui): tela player passa a usar LiveTV; remove MainPlayer.qml"
```

---

## Task 10: Build no CI, validação e release v1.20

**Files:**
- Modify: `CHANGELOG.md` (se existir; senão criar entrada)

- [ ] **Step 1: Atualizar o CHANGELOG**

Adicionar no topo de `CHANGELOG.md` (ajustar formato ao existente):

```markdown
## v1.20 - 2026-05-28

Redesign visual TV DIG+ (Fase 3): tela TV ao Vivo em 3 colunas.
- Barra de topo com abas (Home/TV ao Vivo/Filmes/Séries) + busca + logo.
- Coluna de categorias (group-title dos canais ao vivo) com contagem.
- Coluna de canais filtrada pela categoria; coluna de player + EPG (atual +
  próximos) + botões Playback/Favoritos/Procurar.
- Lista de TV ao Vivo agora mostra apenas canais ao vivo (filtra filmes/séries
  do M3U via classificação por URL).
```

- [ ] **Step 2: Commitar o changelog**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog v1.20"
```

- [ ] **Step 3: Disparar o CI e validar a compilação**

```bash
git push origin main
gh run list --workflow=build.yml --limit 1
gh run watch
```

Esperado: o workflow conclui com sucesso (build verde).

- [ ] **Step 4: Publicar o release**

```bash
git tag v1.20
git push origin v1.20
```

Esperado: o CI gera o release em `https://github.com/mclsousa/SwiftIPTV/releases/latest`.

- [ ] **Step 5: Validação visual (cliente instala)**

Conferir contra o modelo `TV ao Vivo`:
- Barra de topo com as 4 abas + busca + logo à direita; "TV ao Vivo" em amarelo.
- Coluna esquerda lista categorias ao vivo com contagem (ex.: PREMIERE ESPORTES 96).
- Clicar uma categoria preenche a coluna do meio só com os canais dela.
- Clicar um canal reproduz à direita; nome + EPG (atual em amarelo + próximos).
- Botões: "Adicionar/Remover Favoritos" alterna; "Procurar" foca a busca;
  "Playback" mostra "em construção".
- Duplo-clique no vídeo entra/sai de tela cheia (esconde topo+colunas).
- A lista NÃO contém filmes/séries (só ~2.118 canais ao vivo).

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura da spec:** layout 3 colunas (T6-T8), barra de topo (T6), categorias
  ao vivo (T3-T4), filtro live (T1-T2-T4), EPG atual+próximos (T5+T8), botões
  (T8), fullscreen sem auto-hide (T8), Main.qml/CMake/remoção MainPlayer (T9),
  release (T10). ✔ Tudo coberto.
- **Tipos consistentes:** `Channel.type` (T1) usado em T2/T4; `setTypeFilter`/
  `setCategoryFilter`/`TypeRole` (T2) usados em T4/T8; `CategoryListModel`
  (T3) usado em T4; `liveCategoriesModel` (T4) usado em T8; `upcoming()` (T5)
  usado em T8. ✔
- **Sem placeholders:** todo passo de código mostra o código real. ✔
- **Risco residual:** o binding do rótulo do botão Favoritos depende do truque
  `favTick` (Step 1 nota da T8) porque `isFavorite` é função; se ficar
  estranho, alternativa é expor `Q_PROPERTY` de favorito no `StreamPlayer` — não
  necessário para esta entrega.
```
