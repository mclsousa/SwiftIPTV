import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

Item {
    id: root
    anchors.fill: parent
    readonly property var e: diag.engine
    readonly property bool ready: e.healthLevel !== "—" && !e.running

    function levelColor(lvl) {
        if (lvl === "OK")   return Theme.ok
        if (lvl === "WARN") return Theme.warn
        if (lvl === "BAD")  return Theme.bad
        return Theme.subtext
    }
    // Arrays do histórico (mais antigo -> mais novo) p/ os gráficos comparativos.
    function histVals(key) {
        var out = []; var h = diag.history
        for (var i = h.length - 1; i >= 0; i--) { var v = Number(h[i][key]); out.push(isNaN(v) ? 0 : v) }
        return out
    }
    function maxOf(arr, floor) {
        var m = floor || 1; for (var i = 0; i < arr.length; i++) if (arr[i] > m) m = arr[i]; return m
    }

    // ---- Card de métrica (com dica opcional de "ideal") ----
    component Card: Rectangle {
        property string title: ""; property string value: ""; property color vcolor: Theme.text; property string hint: ""
        Layout.fillWidth: true; Layout.preferredHeight: 86
        radius: 12; color: Theme.panel; border.color: Theme.border
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 3
            Text { text: title; color: Theme.subtext; font.pixelSize: 11 }
            Text { text: value === "" ? "—" : value; color: vcolor; font.pixelSize: 16; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { visible: hint !== ""; text: hint; color: Theme.subtext; font.pixelSize: 9 }
        }
    }

    // ---- Termômetro (gauge semicircular) ----
    component Gauge: Item {
        id: g
        property string label: ""
        property real value: 0
        property real maxValue: 100
        property string unit: ""
        property int decimals: 0
        property real good: 0          // limiar "verde"
        property real warn: 0          // limiar "amarelo"
        property bool lowerIsBetter: true
        property bool ready: false
        property string hint: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 138
        function col() {
            if (!g.ready) return Theme.subtext
            if (g.lowerIsBetter) return g.value <= g.good ? Theme.ok : (g.value <= g.warn ? Theme.warn : Theme.bad)
            return g.value >= g.good ? Theme.ok : (g.value >= g.warn ? Theme.warn : Theme.bad)
        }
        Rectangle { anchors.fill: parent; radius: 12; color: Theme.panel; border.color: Theme.border }
        Canvas {
            id: cv
            anchors.fill: parent; anchors.margins: 8
            onPaint: {
                var ctx = getContext('2d'); ctx.reset()
                var cx = width / 2, cy = height * 0.70, r = Math.min(width * 0.40, height * 0.52)
                ctx.lineWidth = 11; ctx.lineCap = 'round'
                ctx.beginPath(); ctx.strokeStyle = Theme.panel2
                ctx.arc(cx, cy, r, Math.PI, 2 * Math.PI); ctx.stroke()
                var frac = (g.ready && g.maxValue > 0) ? Math.max(0, Math.min(1, g.value / g.maxValue)) : 0
                if (frac > 0) {
                    ctx.beginPath(); ctx.strokeStyle = g.col()
                    ctx.arc(cx, cy, r, Math.PI, Math.PI + Math.PI * frac); ctx.stroke()
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 14
            spacing: 1
            Text { anchors.horizontalCenter: parent.horizontalCenter
                text: g.ready ? (g.value.toFixed(g.decimals) + " " + g.unit) : "—"
                color: g.col(); font.pixelSize: 18; font.bold: true }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: g.label; color: Theme.text; font.pixelSize: 12 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; visible: g.hint !== ""; text: g.hint; color: Theme.subtext; font.pixelSize: 9 }
        }
        onValueChanged: cv.requestPaint()
        onReadyChanged: cv.requestPaint()
        onMaxValueChanged: cv.requestPaint()
        Component.onCompleted: cv.requestPaint()
    }

    // ---- Gráfico de barras (comparação entre testes) ----
    component BarChart: Rectangle {
        id: ch
        property string title: ""
        property var values: []
        property real maxValue: 1
        property string barColor: "#8B5CF6"
        Layout.fillWidth: true
        Layout.preferredHeight: 168
        radius: 12; color: Theme.panel; border.color: Theme.border
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 6
            Text { text: ch.title; color: Theme.text; font.pixelSize: 13; font.bold: true }
            Canvas {
                id: cnv
                Layout.fillWidth: true; Layout.fillHeight: true
                onPaint: {
                    var ctx = getContext('2d'); ctx.reset()
                    var vals = ch.values || []; var n = vals.length
                    if (n === 0) {
                        ctx.fillStyle = '#8b93a7'; ctx.font = '12px sans-serif'; ctx.textAlign = 'center'
                        ctx.fillText('Faça um teste para comparar', width / 2, height / 2); return
                    }
                    var bottom = height - 6, top = 16, pad = 4
                    var avail = width - pad * 2
                    var slot = avail / n, bw = Math.min(36, slot * 0.6)
                    var mx = ch.maxValue > 0 ? ch.maxValue : 1
                    for (var i = 0; i < n; i++) {
                        var v = vals[i]; var frac = Math.max(0, Math.min(1, v / mx))
                        var h = (bottom - top) * frac
                        var x = pad + slot * i + (slot - bw) / 2
                        ctx.fillStyle = ch.barColor
                        ctx.fillRect(x, bottom - h, bw, h)
                        ctx.fillStyle = '#cfd6e6'; ctx.font = '9px sans-serif'; ctx.textAlign = 'center'
                        ctx.fillText('' + v, x + bw / 2, bottom - h - 3)
                    }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }
        }
        onValuesChanged: cnv.requestPaint()
        onMaxValueChanged: cnv.requestPaint()
        Component.onCompleted: cnv.requestPaint()
    }

    Connections {
        target: diag.engine
        function onFinished() { Window.window.notify("Diagnóstico concluído") }
    }

    // Cabeçalho
    Rectangle {
        id: header
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 60; color: Theme.panel; border.color: Theme.border
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Button {
                text: "←  Voltar"
                onClicked: app.navigate(auth.authenticated ? "settings" : "login")
                contentItem: Text { text: parent.text; color: Theme.text; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter }
                background: Rectangle { radius: 8; color: Theme.panel2; border.color: Theme.border }
                leftPadding: 12; rightPadding: 12; topPadding: 8; bottomPadding: 8
            }
            Text { text: "Diagnóstico de Rede"; color: Theme.text; font.pixelSize: 18; font.bold: true }
            Item { Layout.fillWidth: true }
            Text { visible: e.running; text: "Analisando... " + e.progress + "%"; color: Theme.subtext; font.pixelSize: 13 }
            Button {
                text: e.running ? "Aguarde..." : "▶ Iniciar teste"
                enabled: !e.running
                onClicked: diag.run()
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                background: Rectangle { radius: 8; color: parent.enabled ? Theme.brand : Theme.panel2 }
                leftPadding: 14; rightPadding: 14; topPadding: 8; bottomPadding: 8
            }
        }
    }

    Flickable {
        anchors.top: header.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 16
        clip: true
        contentWidth: width
        contentHeight: diagCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { }

        ColumnLayout {
            id: diagCol
            width: parent.width
            spacing: 16

            // ---- Health + cards principais ----
            RowLayout {
                Layout.fillWidth: true; spacing: 16

                // Health score
                Rectangle {
                    Layout.preferredWidth: 180; Layout.preferredHeight: 180
                    radius: 16; color: Theme.panel; border.color: Theme.border
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 6
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 96; height: 96; radius: 48
                            color: "transparent"; border.width: 8; border.color: levelColor(e.healthLevel)
                            Text { anchors.centerIn: parent; text: e.healthScore; color: Theme.text; font.pixelSize: 30; font.bold: true }
                        }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Saúde: " + e.healthLevel
                            color: levelColor(e.healthLevel); font.pixelSize: 14; font.bold: true }
                    }
                }

                // Grid de cards
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3; rowSpacing: 12; columnSpacing: 12

                    Card { title: "IPv4"; value: e.ipv4 }
                    Card { title: "IPv6"; value: e.ipv6 }
                    Card { title: "Tipo de rede"; value: e.netType }
                    Card { title: "Latência (média)"; value: e.latencyAvg > 0 ? e.latencyAvg.toFixed(0) + " ms" : ""
                        vcolor: e.latencyAvg===0 ? Theme.text : (e.latencyAvg<80?Theme.ok:(e.latencyAvg<200?Theme.warn:Theme.bad)) }
                    Card { title: "Jitter"; hint: "ideal < 10 ms"
                        value: root.ready ? e.jitter.toFixed(0) + " ms" : ""
                        vcolor: !root.ready ? Theme.text : (e.jitter<10?Theme.ok:(e.jitter<30?Theme.warn:Theme.bad)) }
                    Card { title: "Velocidade"; value: e.speedMbps > 0 ? e.speedMbps.toFixed(1) + " Mbps" : ""
                        vcolor: e.speedMbps===0 ? Theme.text : (e.speedMbps>10?Theme.ok:(e.speedMbps>5?Theme.warn:Theme.bad)) }
                    Card { title: "Perda de pacotes"; hint: "ideal 0%"
                        value: root.ready ? e.packetLoss.toFixed(1) + " %" : ""
                        vcolor: !root.ready ? Theme.text : (e.packetLoss<2?Theme.ok:(e.packetLoss<10?Theme.warn:Theme.bad)) }
                    Card { title: "Localização"; value: (e.geoCity ? e.geoCity + " / " : "") + e.geoCountry }
                    Card { title: "ISP"; value: e.geoIsp }
                    Card { title: "VPN/Proxy"; value: e.vpnText; vcolor: e.vpnDetected ? Theme.warn : Theme.ok }
                }
            }

            // ---- Saúde da internet PARA ASSISTIR ----
            Rectangle {
                Layout.fillWidth: true; radius: 12
                color: Theme.panel; border.width: 2
                border.color: root.ready ? levelColor(e.streamLevel) : Theme.border
                Layout.preferredHeight: 78
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 14
                    Rectangle {
                        width: 46; height: 46; radius: 23
                        color: "transparent"; border.width: 3
                        border.color: root.ready ? levelColor(e.streamLevel) : Theme.border
                        Image { anchors.centerIn: parent
                            source: "qrc:/qt/qml/SwiftIPTV/resources/icons/mi/tv.svg"
                            sourceSize.width: 24; sourceSize.height: 24 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "Saúde da internet para assistir"; color: Theme.subtext; font.pixelSize: 12 }
                        Text { Layout.fillWidth: true
                            text: root.ready ? e.streamText : "Faça um teste para avaliar"
                            color: root.ready ? levelColor(e.streamLevel) : Theme.text
                            font.pixelSize: 18; font.bold: true; elide: Text.ElideRight }
                    }
                }
            }

            // ---- Termômetros (resultado do teste atual) ----
            Text { text: "Termômetros"; color: Theme.text; font.pixelSize: 14; font.bold: true }
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Gauge { label: "Latência"; unit: "ms"; value: e.latencyAvg; maxValue: 300
                    good: 80; warn: 200; lowerIsBetter: true; ready: root.ready }
                Gauge { label: "Jitter"; unit: "ms"; value: e.jitter; maxValue: 80
                    good: 10; warn: 30; lowerIsBetter: true; ready: root.ready; hint: "ideal < 10 ms" }
                Gauge { label: "Velocidade"; unit: "Mbps"; decimals: 1; value: e.speedMbps; maxValue: 50
                    good: 10; warn: 5; lowerIsBetter: false; ready: root.ready }
                Gauge { label: "Perda"; unit: "%"; decimals: 1; value: e.packetLoss; maxValue: 10
                    good: 0; warn: 2; lowerIsBetter: true; ready: root.ready; hint: "ideal 0%" }
            }

            // ---- Gráficos comparando os testes (histórico) ----
            Text { text: "Comparação dos testes"; color: Theme.text; font.pixelSize: 14; font.bold: true }
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                BarChart { title: "Saúde (0–100)"; values: root.histVals("score"); maxValue: 100; barColor: "#8B5CF6" }
                BarChart { title: "Velocidade (Mbps)"; values: root.histVals("speed")
                    maxValue: root.maxOf(root.histVals("speed"), 20); barColor: "#22B8CF" }
                BarChart { title: "Latência (ms)"; values: root.histVals("latency")
                    maxValue: root.maxOf(root.histVals("latency"), 100); barColor: "#F59E0B" }
            }

            // ---- DNS A/B ----
            Rectangle {
                Layout.fillWidth: true; radius: 12; color: Theme.panel; border.color: Theme.border
                Layout.preferredHeight: dnsCol.implicitHeight + 24
                ColumnLayout {
                    id: dnsCol
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Text { text: "Comparação de DNS (DoH)"; color: Theme.text; font.pixelSize: 14; font.bold: true }
                    Repeater {
                        model: e.dnsResults
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true; spacing: 10
                            Text { text: modelData.name; color: Theme.text; font.pixelSize: 13; Layout.preferredWidth: 110 }
                            Text { text: modelData.ms + " ms"; color: Theme.subtext; font.pixelSize: 13; Layout.preferredWidth: 70 }
                            Rectangle { width: 8; height: 8; radius: 4
                                color: modelData.status==="OK"?Theme.ok:(modelData.status==="WARN"?Theme.warn:Theme.bad) }
                            Text { text: modelData.ips; color: Theme.subtext; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }
                    Text { visible: e.dnsResults.length===0; text: "Execute o teste para ver os resultados."; color: Theme.subtext; font.pixelSize: 12 }
                }
            }

            // ---- Servidores IPTV ----
            Rectangle {
                Layout.fillWidth: true; radius: 12; color: Theme.panel; border.color: Theme.border
                Layout.preferredHeight: iptvCol.implicitHeight + 24
                ColumnLayout {
                    id: iptvCol
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Text { text: "Servidores IPTV  " + (e.fastestServer ? "(mais rápido: " + e.fastestServer + ")" : "")
                        color: Theme.text; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    Repeater {
                        model: e.iptvResults
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true; spacing: 10
                            Rectangle { width: 8; height: 8; radius: 4
                                color: modelData.status==="OK"?Theme.ok:(modelData.status==="WARN"?Theme.warn:Theme.bad) }
                            Text { text: modelData.url; color: Theme.text; font.pixelSize: 13; elide: Text.ElideMiddle; Layout.fillWidth: true }
                            Text { text: modelData.ms + " ms"; color: Theme.subtext; font.pixelSize: 13 }
                            Button {
                                text: "Usar este servidor"
                                onClicked: { channels.forceServer(modelData.url); Window.window.notify("Servidor forçado") }
                                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                                background: Rectangle { radius: 6; color: Theme.brand }
                                leftPadding: 10; rightPadding: 10; topPadding: 5; bottomPadding: 5
                            }
                        }
                    }
                    Text { visible: e.iptvResults.length===0; text: "Sem servidores para testar (faça login)."; color: Theme.subtext; font.pixelSize: 12 }
                }
            }

            // ---- Relatório ----
            Rectangle {
                Layout.fillWidth: true; radius: 12; color: Theme.panel; border.color: Theme.border
                Layout.preferredHeight: 300
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Relatório detalhado"; color: Theme.text; font.pixelSize: 14; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Copiar"
                            onClicked: { diag.copyReport(); Window.window.notify("Relatório copiado") }
                            contentItem: Text { text: parent.text; color: Theme.text; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { radius: 6; color: Theme.panel2; border.color: Theme.border }
                            leftPadding: 12; rightPadding: 12; topPadding: 6; bottomPadding: 6
                        }
                        Button {
                            text: "Exportar PDF"
                            onClicked: { var ok = diag.exportPdf(""); Window.window.notify(ok ? "PDF salvo em Documentos" : "Falha ao exportar") }
                            contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { radius: 6; color: Theme.brand }
                            leftPadding: 12; rightPadding: 12; topPadding: 6; bottomPadding: 6
                        }
                    }
                    ScrollView {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        TextArea {
                            readOnly: true; text: diag.report
                            color: Theme.text; font.family: "Consolas"; font.pixelSize: 12
                            background: Rectangle { color: "#0d1322"; radius: 8; border.color: Theme.border }
                            wrapMode: TextArea.NoWrap
                        }
                    }
                }
            }

            // ---- Histórico (caixa rolável, igual ao relatório) ----
            Rectangle {
                Layout.fillWidth: true; radius: 12; color: Theme.panel; border.color: Theme.border
                Layout.preferredHeight: 260
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6
                    Text { text: "Histórico (10 últimos)"; color: Theme.text; font.pixelSize: 14; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8; Layout.rightMargin: 12
                        Text { text: "Data/Hora"; color: Theme.subtext; font.pixelSize: 11; Layout.preferredWidth: 110 }
                        Text { text: "ISP"; color: Theme.subtext; font.pixelSize: 11; Layout.fillWidth: true }
                        Text { text: "Lat."; color: Theme.subtext; font.pixelSize: 11; Layout.preferredWidth: 56 }
                        Text { text: "Jitter"; color: Theme.subtext; font.pixelSize: 11; Layout.preferredWidth: 56 }
                        Text { text: "Vel."; color: Theme.subtext; font.pixelSize: 11; Layout.preferredWidth: 64 }
                        Text { text: "Saúde"; color: Theme.subtext; font.pixelSize: 11; Layout.preferredWidth: 56 }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; opacity: 0.6 }
                    ListView {
                        id: histList
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; model: diag.history; spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { }
                        delegate: RowLayout {
                            required property var modelData
                            width: histList.width - 12; spacing: 8
                            Text { text: modelData.datetime; color: Theme.text; font.pixelSize: 12; Layout.preferredWidth: 110 }
                            Text { text: modelData.isp ? modelData.isp : "—"; color: Theme.text; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: modelData.latency + " ms"; color: Theme.text; font.pixelSize: 12; Layout.preferredWidth: 56 }
                            Text { text: (modelData.jitter ? modelData.jitter : "—") + " ms"; color: Theme.text; font.pixelSize: 12; Layout.preferredWidth: 56 }
                            Text { text: modelData.speed + " Mb"; color: Theme.text; font.pixelSize: 12; Layout.preferredWidth: 64 }
                            Text { text: modelData.health; color: levelColor(modelData.health); font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 56 }
                        }
                        Text { anchors.centerIn: parent; visible: histList.count === 0
                            text: "Nenhum diagnóstico salvo ainda."; color: Theme.subtext; font.pixelSize: 12 }
                    }
                }
            }
        }
    }
}
