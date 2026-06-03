import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "local.sysstat"
  ipcTarget: "local.sysstat"

  property real cpuPercent: 0
  property real memPercent: 0
  property real diskPercent: 0
  property real gpuPercent: -1
  property real loadPercent: 0
  property real memUsedGb: 0
  property real memTotalGb: 0
  property real diskUsedGb: 0
  property real diskTotalGb: 0
  property real gpuMemUsedMb: 0
  property real gpuMemTotalMb: 0
  property int gpuTemp: 0
  property int cpuCores: 1
  property string gpuName: "GPU"
  property string diskMount: "/"
  property real load1: 0
  property real load5: 0
  property real load15: 0
  property var prevCpu: ({ idle: 0, total: 0 })

  readonly property int refreshSeconds: Math.max(1, Number(setting("refreshSeconds", 2)) || 2)
  readonly property string diskPath: String(setting("diskPath", "/") || "/")
  readonly property bool showGpu: boolSetting("showGpu", true)
  readonly property color panelFg: bar ? bar.foreground : Color.foreground
  readonly property string panelFont: bar ? bar.fontFamily : Style.font.family
  readonly property url statusScriptUrl: Qt.resolvedUrl("status.sh")
  readonly property string statusScript: decodeURIComponent(String(statusScriptUrl).replace(/^file:\/\//, ""))

  function boolSetting(key, fallback) {
    var value = setting(key, fallback)
    if (value === true || value === false) return value
    var text = String(value).toLowerCase()
    return text === "true" || text === "1" || text === "yes"
  }

  function refresh() {
    if (!statsProc.running) statsProc.running = true
  }

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

  function mbAsGbText(value) {
    if (!isFinite(value) || value <= 0) return "N/A"
    var gb = value / 1024
    return gb.toFixed(gb >= 10 ? 0 : 1) + " GB"
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

  function updateStats(raw) {
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].trim().split("\t")
      if (parts.length < 2) continue
      if (parts[0] === "cpu") {
        updateCpuTotals(parseInt(parts[1], 10) || 0, parseInt(parts[2], 10) || 0, parseInt(parts[3], 10) || 1)
      } else if (parts[0] === "memory") {
        memPercent = clampPercent(parseNumber(parts[1], 0))
        memUsedGb = parseNumber(parts[2], 0)
        memTotalGb = parseNumber(parts[3], 0)
      } else if (parts[0] === "load") {
        updateLoad(parts[1], parts[2], parts[3])
      } else if (parts[0] === "disk") {
        diskPercent = clampPercent(parseNumber(parts[1], 0))
        diskUsedGb = parseNumber(parts[2], 0)
        diskTotalGb = parseNumber(parts[3], 0)
        diskMount = parts[4] || diskPath
      } else if (parts[0] === "gpu") {
        gpuPercent = parts[1] === "" ? -1 : clampPercent(parseNumber(parts[1], -1))
        gpuMemUsedMb = parseNumber(parts[2], 0)
        gpuMemTotalMb = parseNumber(parts[3], 0)
        gpuTemp = Math.round(parseNumber(parts[4], 0))
        gpuName = parts[5] || "GPU"
      }
    }
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
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.refresh()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.spacing.sm

        Row {
          width: parent.width
          height: Math.max(titleText.implicitHeight, refreshButton.implicitHeight)
          spacing: Style.spacing.rowGap

          Text {
            id: titleText
            width: parent.width - refreshButton.width - Style.spacing.rowGap
            text: "System"
            color: root.panelFg
            font.family: root.panelFont
            font.pixelSize: Style.font.title
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
          }

          Button {
            id: refreshButton
            text: "Refresh"
            foreground: root.panelFg
            fontFamily: root.panelFont
            bordered: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.refresh()
          }
        }

        StatRow {
          width: parent.width
          label: "CPU"
          detail: "Load " + root.load1.toFixed(2) + " · " + root.load5.toFixed(2) + " · " + root.load15.toFixed(2)
          value: root.percentText(root.cpuPercent)
          percent: root.cpuPercent
          badgeText: "󰍛"
          accent: "#7aa2ff"
          foreground: root.panelFg
          fontFamily: root.panelFont
        }

        StatRow {
          width: parent.width
          visible: root.showGpu
          label: root.gpuName === "Unavailable" ? "GPU" : "GPU"
          detail: root.gpuName === "Unavailable"
            ? "Unavailable"
            : root.gpuName + (root.gpuMemTotalMb > 0 ? " · VRAM " + root.mbAsGbText(root.gpuMemUsedMb) + " / " + root.mbAsGbText(root.gpuMemTotalMb) : "") + (root.gpuTemp > 0 ? " · " + root.gpuTemp + " C" : "")
          value: root.percentText(root.gpuPercent)
          percent: root.gpuPercent
          badgeText: "󰢮"
          accent: "#9bd66f"
          foreground: root.panelFg
          fontFamily: root.panelFont
        }

        StatRow {
          width: parent.width
          label: "Memory"
          detail: root.gbText(root.memUsedGb) + " / " + root.gbText(root.memTotalGb)
          value: root.percentText(root.memPercent)
          percent: root.memPercent
          badgeText: "󰘚"
          accent: "#e7b65f"
          foreground: root.panelFg
          fontFamily: root.panelFont
        }

        StatRow {
          width: parent.width
          label: "Disk " + root.diskMount
          detail: root.gbText(root.diskUsedGb) + " / " + root.gbText(root.diskTotalGb)
          value: root.percentText(root.diskPercent)
          percent: root.diskPercent
          badgeText: "󰋊"
          accent: "#c69cff"
          foreground: root.panelFg
          fontFamily: root.panelFont
          showDivider: false
        }
      }
    }
  }

  component StatRow: Item {
    id: row

    property string label: ""
    property string detail: ""
    property string value: ""
    property string badgeText: ""
    property real percent: 0
    property color accent: Color.accent
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    property bool showDivider: true

    implicitHeight: Style.space(74)

    Rectangle {
      id: divider
      visible: row.showDivider
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 1
      color: Qt.rgba(row.foreground.r, row.foreground.g, row.foreground.b, 0.16)
    }

    Row {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.md

      Rectangle {
        id: badge
        width: labelColumn.implicitHeight
        height: width
        radius: Style.cornerRadius
        color: Qt.rgba(row.accent.r, row.accent.g, row.accent.b, 0.22)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          anchors.centerIn: parent
          text: row.badgeText
          color: row.accent
          font.family: row.fontFamily
          font.pixelSize: Style.font.iconLarge
        }
      }

      Column {
        id: labelColumn
        width: parent.width - badge.width - meterColumn.width - Style.spacing.md * 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        Text {
          width: parent.width
          text: row.label
          color: row.foreground
          font.family: row.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: row.detail
          color: Qt.rgba(row.foreground.r, row.foreground.g, row.foreground.b, 0.62)
          font.family: row.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }
      }

      Column {
        id: meterColumn
        width: Style.space(96)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(9)

        Text {
          width: parent.width
          text: row.value
          color: row.accent
          font.family: row.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideRight
        }

        Rectangle {
          width: parent.width
          height: Style.space(5)
          radius: height / 2
          color: Qt.rgba(row.foreground.r, row.foreground.g, row.foreground.b, 0.18)

          Rectangle {
            width: parent.width * Math.max(0, Math.min(100, row.percent)) / 100
            height: parent.height
            radius: parent.radius
            color: row.accent
            visible: row.percent >= 0
          }
        }
      }
    }
  }
}
