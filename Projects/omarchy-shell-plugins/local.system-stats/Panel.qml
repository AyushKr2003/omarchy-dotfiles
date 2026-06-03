import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "local.system-stats"
  ipcTarget: "local.system-stats"

  property real cpuPercent: 0
  property real memPercent: 0
  property real diskPercent: 0
  property real gpuPercent: -1
  property real memUsedGb: 0
  property real memTotalGb: 0
  property real diskUsedGb: 0
  property real diskTotalGb: 0
  property real gpuMemUsedMb: 0
  property real gpuMemTotalMb: 0
  property int gpuTemp: 0
  property string gpuName: "GPU"
  property string diskMount: "/"
  property real load1: 0
  property real load5: 0
  property real load15: 0
  property var cpuHistory: []
  property var memHistory: []
  property var diskHistory: []
  property var gpuHistory: []
  property var prevCpu: ({ idle: 0, total: 0 })

  readonly property int historyLimit: 36
  readonly property int refreshSeconds: Math.max(1, Number(setting("refreshSeconds", 2)) || 2)
  readonly property string diskPath: String(setting("diskPath", "/") || "/")
  readonly property color panelFg: bar ? bar.foreground : Color.foreground
  readonly property string panelFont: bar ? bar.fontFamily : Style.font.family
  readonly property url statusScriptUrl: Qt.resolvedUrl("status.sh")
  readonly property string statusScript: decodeURIComponent(String(statusScriptUrl).replace(/^file:\/\//, ""))

  function refresh() {
    if (!statsProc.running) statsProc.running = true
  }

  function pushHistory(arr, value) {
    var next = arr.slice()
    next.push(Math.max(0, Math.min(100, Number(value) || 0)))
    if (next.length > historyLimit) next.shift()
    return next
  }

  function updateCpuTotals(idle, total) {
    var idleDiff = idle - prevCpu.idle
    var totalDiff = total - prevCpu.total
    if (prevCpu.total > 0 && totalDiff > 0) {
      cpuPercent = Math.max(0, Math.min(100, (1 - idleDiff / totalDiff) * 100))
      cpuHistory = pushHistory(cpuHistory, cpuPercent)
    }
    prevCpu = { idle: idle, total: total }
  }

  function percentText(value) {
    return value < 0 ? "N/A" : Math.round(value) + "%"
  }

  function gbText(value) {
    if (!isFinite(value) || value <= 0) return "N/A"
    return value.toFixed(value >= 10 ? 0 : 1) + " GB"
  }

  function parseNumber(value, fallback) {
    var n = parseFloat(String(value || "").trim())
    return isNaN(n) ? fallback : n
  }

  function updateStats(raw) {
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].trim().split("\t")
      if (parts.length < 2) continue
      if (parts[0] === "cpu") {
        updateCpuTotals(parseInt(parts[1], 10) || 0, parseInt(parts[2], 10) || 0)
      } else if (parts[0] === "memory") {
        memPercent = Math.max(0, Math.min(100, parseNumber(parts[1], 0)))
        memUsedGb = parseNumber(parts[2], 0)
        memTotalGb = parseNumber(parts[3], 0)
        memHistory = pushHistory(memHistory, memPercent)
      } else if (parts[0] === "load") {
        load1 = parseNumber(parts[1], 0)
        load5 = parseNumber(parts[2], 0)
        load15 = parseNumber(parts[3], 0)
      } else if (parts[0] === "disk") {
        diskPercent = Math.max(0, Math.min(100, parseNumber(parts[1], 0)))
        diskUsedGb = parseNumber(parts[2], 0)
        diskTotalGb = parseNumber(parts[3], 0)
        diskMount = parts[4] || diskPath
        diskHistory = pushHistory(diskHistory, diskPercent)
      } else if (parts[0] === "gpu") {
        gpuPercent = parts[1] === "" ? -1 : Math.max(0, Math.min(100, parseNumber(parts[1], -1)))
        gpuMemUsedMb = parseNumber(parts[2], 0)
        gpuMemTotalMb = parseNumber(parts[3], 0)
        gpuTemp = Math.round(parseNumber(parts[4], 0))
        gpuName = parts[5] || "GPU"
        if (gpuPercent >= 0) gpuHistory = pushHistory(gpuHistory, gpuPercent)
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
    // tooltipText: "System stats"
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
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.refresh()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.spacing.md

        Row {
          width: parent.width
          spacing: Style.spacing.rowGap

          Text {
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
            onClicked: root.refresh()
          }
        }

        StatCard {
          width: parent.width
          title: "CPU"
          value: root.percentText(root.cpuPercent)
          detail: "Load " + root.load1.toFixed(2) + " / " + root.load5.toFixed(2) + " / " + root.load15.toFixed(2)
          percent: root.cpuPercent
          history: root.cpuHistory
          foreground: root.panelFg
          fontFamily: root.panelFont
        }

        StatCard {
          width: parent.width
          title: "GPU"
          value: root.percentText(root.gpuPercent)
          detail: root.gpuName + (root.gpuMemTotalMb > 0 ? " · VRAM " + Math.round(root.gpuMemUsedMb) + " / " + Math.round(root.gpuMemTotalMb) + " MB" : "") + (root.gpuTemp > 0 ? " · " + root.gpuTemp + " C" : "")
          percent: root.gpuPercent
          history: root.gpuHistory
          foreground: root.panelFg
          fontFamily: root.panelFont
        }

        StatCard {
          width: parent.width
          title: "Memory"
          value: root.percentText(root.memPercent)
          detail: root.gbText(root.memUsedGb) + " / " + root.gbText(root.memTotalGb)
          percent: root.memPercent
          history: root.memHistory
          foreground: root.panelFg
          fontFamily: root.panelFont
        }

        StatCard {
          width: parent.width
          title: "Disk"
          value: root.percentText(root.diskPercent)
          detail: root.diskMount + " · " + root.gbText(root.diskUsedGb) + " / " + root.gbText(root.diskTotalGb)
          percent: root.diskPercent
          history: root.diskHistory
          foreground: root.panelFg
          fontFamily: root.panelFont
        }
      }
    }
  }

  component StatCard: Rectangle {
    id: card

    property string title: ""
    property string value: ""
    property string detail: ""
    property real percent: 0
    property var history: []
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family

    implicitHeight: content.implicitHeight + Style.spacing.rowPaddingX * 2
    radius: Style.cornerRadius
    color: Style.normalFillFor(foreground, Color.accent)
    border.color: Style.normalBorderFor(foreground, Color.accent)
    border.width: Style.normalBorderWidth

    Column {
      id: content
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.rightMargin: Style.spacing.rowPaddingX
      spacing: Style.spacing.sm

      Row {
        width: parent.width

        Text {
          text: card.title
          width: parent.width - valueText.width
          color: card.foreground
          font.family: card.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          id: valueText
          text: card.value
          color: card.foreground
          font.family: card.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
      }

      Rectangle {
        width: parent.width
        height: Style.space(8)
        radius: height / 2
        color: Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b, 0.14)

        Rectangle {
          width: parent.width * Math.max(0, Math.min(100, card.percent)) / 100
          height: parent.height
          radius: parent.radius
          color: Color.accent
          visible: card.percent >= 0
        }
      }

      Canvas {
        width: parent.width
        height: Style.space(34)
        property var points: card.history
        onPointsChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          if (!points || points.length === 0) return
          ctx.strokeStyle = card.foreground
          ctx.fillStyle = Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b, 0.18)
          ctx.lineWidth = 1.4
          ctx.beginPath()
          var step = width / Math.max(1, points.length - 1)
          for (var i = 0; i < points.length; i++) {
            var x = i * step
            var y = height - (points[i] / 100) * (height - 2) - 1
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
          }
          ctx.stroke()
          ctx.lineTo(width, height)
          ctx.lineTo(0, height)
          ctx.closePath()
          ctx.fill()
        }
      }

      Text {
        text: card.detail
        width: parent.width
        color: Qt.darker(card.foreground, 1.45)
        font.family: card.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }
}
