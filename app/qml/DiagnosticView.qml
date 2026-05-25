import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import SwiftIPTV

Item {
    id: root
    anchors.fill: parent
    readonly property var e: diag.engine

    // Card reutilizável (inline component — precisa estar no nível raiz do arquivo)
    component Card: Rectangle {
        property string title: ""; property string value: ""; property color vcolor: Theme.text
        Layout.fillWidth: true; Layout.preferredHeight: 78
        radius: 12; color: Theme.panel; border.color: Theme.border
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 4
            Text { text: title; color: Theme.subtext; font.pixelSize: 11 }
            Text { text: value === "" ? "—" : value; color: vcolor; font.pixelSize: 16; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }

    function levelColor(lvl) {
        if (lvl === "OK")   return Theme.ok
        if (lvl === "WARN") return Theme.warn
        if (lvl === "BAD")  return Theme.bad
        return Theme.subtext
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
                onClicked: app.navigate(auth.authenticated ? "player" : "login")
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

    ScrollView {
        anchors.top: header.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 16
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
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
                    Card { title: "Velocidade"; value: e.speedMbps > 0 ? e.speedMbps.toFixed(1) + " Mbps" : ""
                        vcolor: e.speedMbps===0 ? Theme.text : (e.speedMbps>10?Theme.ok:(e.speedMbps>5?Theme.warn:Theme.bad)) }
                    Card { title: "Perda de pacotes"; value: e.packetLoss.toFixed(1) + " %"
                        vcolor: e.packetLoss<5?Theme.ok:(e.packetLoss<15?Theme.warn:Theme.bad) }
                    Card { title: "Localização"; value: (e.geoCity ? e.geoCity + " / " : "") + e.geoCountry }
                    Card { title: "ISP"; value: e.geoIsp }
                    Card { title: "VPN/Proxy"; value: e.vpnText; vcolor: e.vpnDetected ? Theme.warn : Theme.ok }
                }
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

            // ---- Histórico ----
            Rectangle {
                Layout.fillWidth: true; radius: 12; color: Theme.panel; border.color: Theme.border
                Layout.preferredHeight: histCol.implicitHeight + 24
                ColumnLayout {
                    id: histCol
                    anchors.fill: parent; anchors.margins: 12; spacing: 6
                    Text { text: "Histórico (10 últimos)"; color: Theme.text; font.pixelSize: 14; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "Data/Hora"; color: Theme.subtext; font.pixelSize: 11; Layout.preferredWidth: 120 }
                        Text { text: "IP"; color: Theme.subtext; font.pixelSize: 11; Layout.preferredWidth: 120 }
                        Text { text: "ISP"; color: Theme.subtext; font.pixelSize: 11; Layout.fillWidth: true }
                        Text { text: "Lat."; color: Theme.subtext; font.pixelSize: 11; Layout.preferredWidth: 60 }
                        Text { text: "Vel."; color: Theme.subtext; font.pixelSize: 11; Layout.preferredWidth: 70 }
                        Text { text: "Saúde"; color: Theme.subtext; font.pixelSize: 11; Layout.preferredWidth: 60 }
                    }
                    Repeater {
                        model: diag.history
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true; spacing: 8
                            Text { text: modelData.datetime; color: Theme.text; font.pixelSize: 12; Layout.preferredWidth: 120 }
                            Text { text: modelData.ip; color: Theme.text; font.pixelSize: 12; Layout.preferredWidth: 120 }
                            Text { text: modelData.isp; color: Theme.text; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: modelData.latency + " ms"; color: Theme.text; font.pixelSize: 12; Layout.preferredWidth: 60 }
                            Text { text: modelData.speed + " Mb"; color: Theme.text; font.pixelSize: 12; Layout.preferredWidth: 70 }
                            Text { text: modelData.health; color: levelColor(modelData.health); font.pixelSize: 12; Layout.preferredWidth: 60 }
                        }
                    }
                    Text { visible: diag.history.length===0; text: "Nenhum diagnóstico salvo ainda."; color: Theme.subtext; font.pixelSize: 12 }
                }
            }
        }
    }
}
