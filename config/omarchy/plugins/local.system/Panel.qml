import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "local.system"
  ipcTarget: "local.system"

  // ── Telemetry State ──────────────────────────────────────────────────────
  property real cpuPercent: 0
  property real memPercent: 0
  property real swapPercent: 0
  property real diskPercent: 0
  property real gpuPercent: -1
  property real loadPercent: 0

  property real memUsedGb: 0
  property real memTotalGb: 0
  property real memAvailGb: 0
  property real memFreeGb: 0
  property real memCacheGb: 0

  property real swapUsedGb: 0
  property real swapTotalGb: 0
  property real diskUsedGb: 0
  property real diskTotalGb: 0
  property real gpuMemUsedMb: 0
  property real gpuMemTotalMb: 0
  property int gpuTemp: 0
  property int cpuTemp: 0
  property int cpuCores: 1
  property string gpuName: "GPU"
  property string diskMount: "/"

  property real load1: 0
  property real load5: 0
  property real load15: 0
  property var prevCpu: ({ idle: 0, total: 0 })
  property var prevCores: ({})
  property var corePctList: []

  property real prevRxBytes: 0
  property real prevTxBytes: 0
  property real rxSpeed: 0
  property real txSpeed: 0
  property real totalRxMb: 0
  property real totalTxMb: 0

  readonly property int refreshSeconds: Math.max(1, Number(setting("refreshSeconds", 2)) || 2)
  readonly property string diskPath: String(setting("diskPath", "/") || "/")

  readonly property url statusScriptUrl: Qt.resolvedUrl("status.sh")
  readonly property string statusScript: decodeURIComponent(String(statusScriptUrl).replace(/^file:\/\//, ""))

  // Native Omarchy Theme Colors
  readonly property color colorCpu: Color.accent
  readonly property color colorMem: Color.accent
  readonly property color colorSwap: Color.accent
  readonly property color colorDisk: Color.accent
  readonly property color colorTemp: Color.accent
  readonly property color colorNet: Color.accent
  readonly property color colorGpu: Color.accent

  function clampPercent(value) {
    if (!isFinite(value)) return 0
    return Math.max(0, Math.min(100, value))
  }

  function parseNumber(value, fallback) {
    var n = parseFloat(String(value || "").trim())
    return isNaN(n) ? fallback : n
  }

  function percentText(value) {
    return value < 0 ? "N/A" : Math.round(value) + "%"
  }

  function gbText(value) {
    if (!isFinite(value) || value <= 0) return "N/A"
    return value.toFixed(value >= 10 ? 0 : 1) + " GB"
  }

  function speedText(bytesPerSec) {
    if (!isFinite(bytesPerSec) || bytesPerSec <= 0) return "0 B/s"
    if (bytesPerSec >= 1048576) return (bytesPerSec / 1048576).toFixed(1) + " MB/s"
    if (bytesPerSec >= 1024) return (bytesPerSec / 1024).toFixed(0) + " KB/s"
    return Math.round(bytesPerSec) + " B/s"
  }

  function mbOrGbText(mb) {
    if (!isFinite(mb) || mb <= 0) return "0 MB"
    if (mb >= 1024) return (mb / 1024).toFixed(1) + " GB"
    return Math.round(mb) + " MB"
  }

  function statusColorFor(pct, fallbackColor) {
    var alt = (fallbackColor !== undefined && fallbackColor !== null) ? fallbackColor : Color.accent
    var n = Number(pct)
    if (isNaN(n)) return alt
    if (n >= 85) return Color.urgent
    return alt
  }

  function updateCpuTotals(idle, total, cores) {
    cpuCores = Math.max(1, cores || 1)
    var idleDiff = idle - prevCpu.idle
    var totalDiff = total - prevCpu.total
    if (prevCpu.total > 0 && totalDiff > 0) {
      cpuPercent = clampPercent((1 - idleDiff / totalDiff) * 100)
    }
    prevCpu = { idle: idle, total: total }
    loadPercent = clampPercent((load1 / cpuCores) * 100)
  }

  function updateLoad(one, five, fifteen) {
    load1 = parseNumber(one, 0)
    load5 = parseNumber(five, 0)
    load15 = parseNumber(fifteen, 0)
    loadPercent = clampPercent((load1 / Math.max(1, cpuCores)) * 100)
  }

  function updateNet(rx, tx) {
    var r = parseNumber(rx, 0)
    var t = parseNumber(tx, 0)
    if (prevRxBytes > 0 && r >= prevRxBytes) {
      rxSpeed = (r - prevRxBytes) / refreshSeconds
    }
    if (prevTxBytes > 0 && t >= prevTxBytes) {
      txSpeed = (t - prevTxBytes) / refreshSeconds
    }
    prevRxBytes = r
    prevTxBytes = t
    totalRxMb = r / (1024 * 1024)
    totalTxMb = t / (1024 * 1024)
  }

  function updateStats(raw) {
    var lines = String(raw || "").split("\n")
    var newCores = []
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].trim().split("\t")
      if (parts.length < 2) continue
      if (parts[0] === "cpu") {
        updateCpuTotals(parseInt(parts[1], 10) || 0, parseInt(parts[2], 10) || 0, parseInt(parts[3], 10) || 1)
      } else if (parts[0] === "cpucore") {
        var cId = parts[1]
        var cIdle = parseInt(parts[2], 10) || 0
        var cTot = parseInt(parts[3], 10) || 0
        var pCore = prevCores[cId]
        var cPct = 0
        if (pCore && cTot > pCore.total && cTot - pCore.total > 0) {
          cPct = clampPercent((1 - (cIdle - pCore.idle) / (cTot - pCore.total)) * 100)
        }
        prevCores[cId] = { idle: cIdle, total: cTot }
        var coreNum = cId.replace(/^cpu/, "")
        newCores.push({ name: "Core " + coreNum, pct: cPct })
      } else if (parts[0] === "memory") {
        memPercent = clampPercent(parseNumber(parts[1], 0))
        memUsedGb = parseNumber(parts[2], 0)
        memTotalGb = parseNumber(parts[3], 0)
        memAvailGb = parseNumber(parts[4], 0)
        memFreeGb = parseNumber(parts[5], 0)
        memCacheGb = parseNumber(parts[6], 0)
        swapPercent = clampPercent(parseNumber(parts[7], 0))
        swapUsedGb = parseNumber(parts[8], 0)
        swapTotalGb = parseNumber(parts[9], 0)
      } else if (parts[0] === "load") {
        updateLoad(parts[1], parts[2], parts[3])
      } else if (parts[0] === "disk") {
        diskPercent = clampPercent(parseNumber(parts[1], 0))
        diskUsedGb = parseNumber(parts[2], 0)
        diskTotalGb = parseNumber(parts[3], 0)
        diskMount = parts[4] || diskPath
      } else if (parts[0] === "net") {
        updateNet(parts[1], parts[2])
      } else if (parts[0] === "temp") {
        cpuTemp = Math.round(parseNumber(parts[1], 0))
        if (parts[2]) gpuTemp = Math.round(parseNumber(parts[2], 0))
      } else if (parts[0] === "gpu") {
        gpuPercent = parts[1] === "" ? -1 : clampPercent(parseNumber(parts[1], -1))
        gpuMemUsedMb = parseNumber(parts[2], 0)
        gpuMemTotalMb = parseNumber(parts[3], 0)
        if (parseNumber(parts[4], 0) > 0) gpuTemp = Math.round(parseNumber(parts[4], 0))
        gpuName = parts[5] || "GPU"
      }
    }
    if (newCores.length > 0) corePctList = newCores
  }

  function refresh() {
    if (!statsProc.running) statsProc.running = true
  }

  Component.onCompleted: refresh()

  Process {
    id: statsProc
    command: ["bash", root.statusScript, root.diskPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateStats(text)
    }
  }

  Timer {
    interval: root.refreshSeconds * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ── Bar Widget Button (Only Memory Icon) ─────────────────────────────────
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍛"
    horizontalMargin: 7.5
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) {
        root.refresh()
        root.toggle()
      } else {
        root.close()
        if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
      }
    }
  }

  // ── Popout Panel ────────────────────────────────────────────────────────
  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(560))
    contentHeight: popup.fittedContentHeight(mainColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: {
        root.close()
        if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
      }

      Column {
        id: mainColumn
        width: parent.width
        spacing: Style.spacing.panelGap

        // ── ROW 1: CPU Card (Full Width) ──────────────────────────────────
        BorderSurface {
          width: parent.width
          implicitHeight: cpuCol.implicitHeight + Style.spacing.panelPadding * 2
          color: Color.menu.background
          border.width: Style.normalBorderWidth
          border.color: Color.menu.border
          radius: Style.cornerRadius

          Column {
            id: cpuCol
            width: parent.width - Style.spacing.panelPadding * 2
            anchors.centerIn: parent
            spacing: Style.spacing.rowGap

            Item {
              width: parent.width
              height: cpuHeaderTitle.implicitHeight

              Text {
                id: cpuHeaderTitle
                anchors.left: parent.left
                text: "󰍛  CPU"
                color: root.colorCpu
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.weight: Font.DemiBold
              }
              Text {
                anchors.right: parent.right
                text: root.percentText(root.cpuPercent)
                color: root.statusColorFor(root.cpuPercent, root.colorCpu)
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.weight: Font.DemiBold
              }
            }

            Item {
              width: parent.width
              height: Style.space(7)
              Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Color.foreground
                opacity: 0.08
              }
              Rectangle {
                height: parent.height
                radius: height / 2
                width: parent.width * (root.cpuPercent / 100)
                color: root.statusColorFor(root.cpuPercent, root.colorCpu)
              }
            }

            // Subtitle for cores
            Text {
              text: "PER-CORE USAGE"
              color: Color.foreground
              opacity: 0.4
              font.family: Style.font.family
              font.pixelSize: Style.space(9)
              font.weight: Font.Bold
              visible: root.corePctList.length > 0
            }

            // Per-Core Grid (2 Columns of Cores, Max 4 Rows Height with Scroll)
            Flickable {
              id: coreFlick
              width: parent.width
              height: Math.min(coreGrid.implicitHeight, Style.space(80))
              contentWidth: width
              contentHeight: coreGrid.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              flickableDirection: Flickable.VerticalFlick
              interactive: contentHeight > height
              visible: root.corePctList.length > 0

              Grid {
                id: coreGrid
                width: coreFlick.width
                columns: 2
                spacing: Style.space(8)

                Repeater {
                  model: root.corePctList

                  Item {
                    width: (parent.width - Style.space(8)) / 2
                    height: Style.space(14)

                    Row {
                      anchors.fill: parent
                      spacing: Style.space(6)

                      Text {
                        text: modelData.name
                        color: Color.foreground
                        opacity: 0.6
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        width: Style.space(48)
                      }

                      Item {
                        width: parent.width - Style.space(48) - Style.space(36) - Style.space(12)
                        height: Style.space(5)
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                          anchors.fill: parent
                          radius: height / 2
                          color: Color.foreground
                          opacity: 0.08
                        }
                        Rectangle {
                          height: parent.height
                          radius: height / 2
                          width: parent.width * (modelData.pct / 100)
                          color: root.statusColorFor(modelData.pct, root.colorCpu)
                        }
                      }

                      Text {
                        text: Math.round(modelData.pct) + "%"
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.weight: Font.Bold
                        width: Style.space(36)
                        horizontalAlignment: Text.AlignRight
                      }
                    }
                  }
                }
              }
            }

            Text {
              width: parent.width
              text: "Cores: " + root.cpuCores + "  │  Load: " + root.load1 + " (1m)  " + root.load5 + " (5m)  " + root.load15 + " (15m)"
              color: Color.foreground
              opacity: 0.6
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }
        }

        // ── ROW 2: Memory (Col 1) & Disk (Col 2) ──────────────────────────
        Row {
          width: parent.width
          spacing: Style.spacing.panelGap

          // Memory Card (Col 1)
          BorderSurface {
            width: (parent.width - Style.spacing.panelGap) / 2
            implicitHeight: Math.max(memCol.implicitHeight, diskCol.implicitHeight) + Style.spacing.panelPadding * 2
            color: Color.menu.background
            border.width: Style.normalBorderWidth
            border.color: Color.menu.border
            radius: Style.cornerRadius

            Column {
              id: memCol
              width: parent.width - Style.spacing.panelPadding * 2
              anchors.centerIn: parent
              spacing: Style.spacing.rowGap

              Item {
                width: parent.width
                height: memHeaderTitle.implicitHeight

                Text {
                  id: memHeaderTitle
                  anchors.left: parent.left
                  text: "󰘚  Memory"
                  color: root.colorMem
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.weight: Font.DemiBold
                }
                Text {
                  anchors.right: parent.right
                  text: root.percentText(root.memPercent)
                  color: root.statusColorFor(root.memPercent, root.colorMem)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.weight: Font.DemiBold
                }
              }

              Item {
                width: parent.width
                height: Style.space(7)
                Rectangle {
                  anchors.fill: parent
                  radius: height / 2
                  color: Color.foreground
                  opacity: 0.08
                }
                Rectangle {
                  height: parent.height
                  radius: height / 2
                  width: parent.width * (root.memPercent / 100)
                  color: root.statusColorFor(root.memPercent, root.colorMem)
                }
              }

              Text {
                width: parent.width
                text: "RAM Used: " + root.gbText(root.memUsedGb) + " / " + root.gbText(root.memTotalGb)
                color: Color.foreground
                opacity: 0.7
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: "Available: " + root.gbText(root.memAvailGb) + "  │  Free: " + root.gbText(root.memFreeGb)
                color: Color.foreground
                opacity: 0.5
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              // Separator for Swap
              Rectangle {
                width: parent.width
                height: 1
                color: Color.foreground
                opacity: 0.1
              }

              // Swap Section
              Item {
                width: parent.width
                height: swapHeaderTitle.implicitHeight

                Text {
                  id: swapHeaderTitle
                  anchors.left: parent.left
                  text: "Swap"
                  color: Color.foreground
                  opacity: 0.6
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.weight: Font.DemiBold
                }
                Text {
                  anchors.right: parent.right
                  text: root.percentText(root.swapPercent)
                  color: root.colorSwap
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.weight: Font.DemiBold
                }
              }

              Item {
                width: parent.width
                height: Style.space(5)
                Rectangle {
                  anchors.fill: parent
                  radius: height / 2
                  color: Color.foreground
                  opacity: 0.08
                }
                Rectangle {
                  height: parent.height
                  radius: height / 2
                  width: parent.width * (root.swapPercent / 100)
                  color: root.colorSwap
                }
              }

              Text {
                width: parent.width
                text: "Swap: " + root.gbText(root.swapUsedGb) + " / " + root.gbText(root.swapTotalGb)
                color: Color.foreground
                opacity: 0.6
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
          }

          // Disk Card (Col 2)
          BorderSurface {
            width: (parent.width - Style.spacing.panelGap) / 2
            implicitHeight: Math.max(memCol.implicitHeight, diskCol.implicitHeight) + Style.spacing.panelPadding * 2
            color: Color.menu.background
            border.width: Style.normalBorderWidth
            border.color: Color.menu.border
            radius: Style.cornerRadius

            Column {
              id: diskCol
              width: parent.width - Style.spacing.panelPadding * 2
              anchors.centerIn: parent
              spacing: Style.spacing.rowGap

              Item {
                width: parent.width
                height: diskHeaderTitle.implicitHeight

                Text {
                  id: diskHeaderTitle
                  anchors.left: parent.left
                  text: "󰋊  Disk (" + root.diskMount + ")"
                  color: root.colorDisk
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.weight: Font.DemiBold
                }
                Text {
                  anchors.right: parent.right
                  text: root.percentText(root.diskPercent)
                  color: root.statusColorFor(root.diskPercent, root.colorDisk)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.weight: Font.DemiBold
                }
              }

              Item {
                width: parent.width
                height: Style.space(7)
                Rectangle {
                  anchors.fill: parent
                  radius: height / 2
                  color: Color.foreground
                  opacity: 0.08
                }
                Rectangle {
                  height: parent.height
                  radius: height / 2
                  width: parent.width * (root.diskPercent / 100)
                  color: root.statusColorFor(root.diskPercent, root.colorDisk)
                }
              }

              Text {
                width: parent.width
                text: "Used: " + root.gbText(root.diskUsedGb)
                color: Color.foreground
                opacity: 0.7
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: "Total: " + root.gbText(root.diskTotalGb)
                color: Color.foreground
                opacity: 0.7
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: "Mount: " + root.diskMount
                color: Color.foreground
                opacity: 0.5
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
          }
        }

        // ── ROW 3: Temperature (Col 1) & Network (Col 2) ───────────────────
        Row {
          width: parent.width
          spacing: Style.spacing.panelGap

          // Temperature Card (Col 1)
          BorderSurface {
            width: (parent.width - Style.spacing.panelGap) / 2
            implicitHeight: Math.max(tempCol.implicitHeight, netCol.implicitHeight) + Style.spacing.panelPadding * 2
            color: Color.menu.background
            border.width: Style.normalBorderWidth
            border.color: Color.menu.border
            radius: Style.cornerRadius

            Column {
              id: tempCol
              width: parent.width - Style.spacing.panelPadding * 2
              anchors.centerIn: parent
              spacing: Style.spacing.rowGap

              Item {
                width: parent.width
                height: tempHeaderTitle.implicitHeight

                Text {
                  id: tempHeaderTitle
                  anchors.left: parent.left
                  text: "󰔏  Temp"
                  color: root.colorTemp
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.weight: Font.DemiBold
                }
                Text {
                  anchors.right: parent.right
                  text: (root.cpuTemp > 0 ? root.cpuTemp + "°C" : "N/A")
                  color: root.statusColorFor(root.cpuTemp > 75 ? 85 : 40, root.colorTemp)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.weight: Font.DemiBold
                }
              }

              Text {
                width: parent.width
                text: "CPU Package: " + (root.cpuTemp > 0 ? root.cpuTemp + "°C" : "N/A")
                color: Color.foreground
                opacity: 0.7
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.gpuName + ": " + (root.gpuTemp > 0 ? root.gpuTemp + "°C" : "N/A")
                color: Color.foreground
                opacity: 0.7
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
          }

          // Network Card (Col 2)
          BorderSurface {
            width: (parent.width - Style.spacing.panelGap) / 2
            implicitHeight: Math.max(tempCol.implicitHeight, netCol.implicitHeight) + Style.spacing.panelPadding * 2
            color: Color.menu.background
            border.width: Style.normalBorderWidth
            border.color: Color.menu.border
            radius: Style.cornerRadius

            Column {
              id: netCol
              width: parent.width - Style.spacing.panelPadding * 2
              anchors.centerIn: parent
              spacing: Style.spacing.rowGap

              Item {
                width: parent.width
                height: netHeaderTitle.implicitHeight

                Text {
                  id: netHeaderTitle
                  anchors.left: parent.left
                  text: "󰖩  Network"
                  color: root.colorNet
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.weight: Font.DemiBold
                }
                Text {
                  anchors.right: parent.right
                  text: root.speedText(root.rxSpeed + root.txSpeed)
                  color: root.colorNet
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.weight: Font.DemiBold
                }
              }

              Text {
                width: parent.width
                text: "Down (Rx): " + root.speedText(root.rxSpeed) + " (" + root.mbOrGbText(root.totalRxMb) + ")"
                color: Color.foreground
                opacity: 0.7
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: "Up (Tx): " + root.speedText(root.txSpeed) + " (" + root.mbOrGbText(root.totalTxMb) + ")"
                color: Color.foreground
                opacity: 0.7
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
          }
        }

        // ── ROW 4: GPU Card (Full Width - Optional) ─────────────────────────
        BorderSurface {
          width: parent.width
          implicitHeight: gpuCol.implicitHeight + Style.spacing.panelPadding * 2
          color: Color.menu.background
          border.width: Style.normalBorderWidth
          border.color: Color.menu.border
          radius: Style.cornerRadius
          visible: root.gpuPercent >= 0 || root.gpuTemp > 0

          Column {
            id: gpuCol
            width: parent.width - Style.spacing.panelPadding * 2
            anchors.centerIn: parent
            spacing: Style.spacing.rowGap

            Item {
              width: parent.width
              height: gpuHeaderTitle.implicitHeight

              Text {
                id: gpuHeaderTitle
                anchors.left: parent.left
                text: "󰢮  " + root.gpuName + (root.gpuTemp > 0 ? (" (" + root.gpuTemp + "°C)") : "")
                color: root.colorGpu
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.weight: Font.DemiBold
              }
              Text {
                anchors.right: parent.right
                text: root.percentText(root.gpuPercent)
                color: root.statusColorFor(root.gpuPercent, root.colorGpu)
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.weight: Font.DemiBold
                visible: root.gpuPercent >= 0
              }
            }

            Item {
              width: parent.width
              height: Style.space(7)
              visible: root.gpuPercent >= 0
              Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Color.foreground
                opacity: 0.08
              }
              Rectangle {
                height: parent.height
                radius: height / 2
                width: parent.width * (root.gpuPercent / 100)
                color: root.statusColorFor(root.gpuPercent, root.colorGpu)
              }
            }

            Text {
              width: parent.width
              text: "VRAM Used: " + Math.round(root.gpuMemUsedMb) + " MB / " + Math.round(root.gpuMemTotalMb) + " MB"
              color: Color.foreground
              opacity: 0.7
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              visible: root.gpuMemTotalMb > 0
            }
          }
        }
      }
    }
  }
}
