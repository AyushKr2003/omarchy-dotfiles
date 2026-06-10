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

  // ── Phrases ──────────────────────────────────────────────────────────────
  // Rotated in the panel header while it's open. Each group reflects the
  // dominant system condition so the label always feels contextual.
  // Style: present-participle verb + noun, playful, ≤ 3 words — same
  // register as bluetooth/power/tailscale/dropbox panels in omarchy-shell.

  // Shown when everything is calm (cpu < 40, mem < 60, disk < 75)
  readonly property var idlePhrases: [
    "Watching electrons",
    "Counting cycles",
    "Minding registers",
    "Tending clocks",
    "Nursing circuits",
    "Herding threads",
    "Babysitting bits",
    "Sipping watts",
    "Chilling cores",
    "Tickling timers",
    "Humming quietly",
    "Resting processes",
    "Lounging threads",
    "Stretching cycles",
    "Napping kernels",
    "Breathing easy",
    "Spinning peacefully",
    "Idling gracefully",
    "Killing time",
    "Watching clocks"
  ]

  // Shown when CPU is busy (cpu >= 40 && cpu < 75)
  readonly property var cpuBusyPhrases: [
    "Crunching numbers",
    "Churning cycles",
    "Burning silicon",
    "Mashing instructions",
    "Grinding cores",
    "Chewing workloads",
    "Flipping bits",
    "Racing pipelines",
    "Juggling threads",
    "Feeding the cores",
    "Spinning fast",
    "Pushing pipelines",
    "Flexing muscles",
    "Processing thoughts",
    "Earning its keep",
    "Working overtime",
    "Cooking instructions",
    "Herding processes",
    "Scheduling madly",
    "Dispatching furiously"
  ]

  // Shown when CPU is pegged (cpu >= 75)
  readonly property var cpuHotPhrases: [
    "Melting cores",
    "Sweating silicon",
    "Screaming registers",
    "Frying pipelines",
    "Roasting threads",
    "Burning everything",
    "Maxing out",
    "Sprinting hard",
    "Gasping for cycles",
    "Begging for cores",
    "Thrashing madly",
    "Overclocking dignity",
    "Blowing fans",
    "Redlining hard",
    "Cooking alive",
    "Panic scheduling",
    "Pegging everything",
    "Screaming loudly",
    "Hitting limits",
    "Crying in silicon"
  ]

  // Shown when memory is full (mem >= 75)
  readonly property var memHeavyPhrases: [
    "Hoarding memory",
    "Swapping secrets",
    "Squeezing RAM",
    "Taxing pages",
    "Stressing allocators",
    "Filling buckets",
    "Juggling pages",
    "Borrowing headroom",
    "Paging furiously",
    "Leaking slowly",
    "Cramming heaps",
    "Swapping sweat",
    "Begging for RAM",
    "Compressing madly",
    "Evicting pages",
    "Hunting free blocks",
    "Battling fragmentation",
    "Starving allocations",
    "Crying for swap",
    "Counting bytes"
  ]

  // Shown when disk is filling up (disk >= 75)
  readonly property var diskFullPhrases: [
    "Running out",
    "Hoarding inodes",
    "Packing storage",
    "Filling shelves",
    "Cramming blocks",
    "Sweeping clusters",
    "Defragging dignity",
    "Begging for space",
    "Hunting orphans",
    "Evicting files",
    "Counting sectors",
    "Busting quotas",
    "Leaking gigabytes",
    "Groaning quietly",
    "Eating storage",
    "Maxing partitions",
    "Losing free space",
    "Filing everything",
    "Packing tightly",
    "Drowning in data"
  ]

  // Shown when GPU is working hard (gpu >= 60)
  readonly property var gpuBusyPhrases: [
    "Shading pixels",
    "Melting textures",
    "Grinding polygons",
    "Rasterizing madly",
    "Blasting shaders",
    "Cooking vertices",
    "Tracing rays",
    "Tensor crunching",
    "Painting frames",
    "Drawing everything",
    "Burning VRAM",
    "Rendering hard",
    "Fusing pixels",
    "Sampling madly",
    "Uploading madness",
    "Smashing triangles",
    "Dispatching kernels",
    "Torturing CUDA",
    "Sprinting shaders",
    "Parallelizing pain"
  ]

  // Shown when GPU is hot (gpuTemp >= 75)
  readonly property var gpuHotPhrases: [
    "Smelting silicon",
    "Roasting VRAM",
    "Boiling drivers",
    "Sweating pixels",
    "Thermal throttling",
    "Begging for airflow",
    "Screaming in CUDA",
    "Vaporizing frames",
    "Overheating quietly",
    "Frying shaders",
    "Melting quietly",
    "Blowing the budget",
    "Throttling gently",
    "Cooking polygons",
    "Burning runway",
    "Toasting die",
    "Hitting junction",
    "Asking for cooling",
    "Radiating heat",
    "Flirting with limits"
  ]

  property int phraseIndex: 0

  // Pick the most contextually relevant phrase list based on current stats.
  // Priority: GPU hot > CPU hot > mem heavy > disk full > GPU busy > CPU busy > idle
  readonly property var activePhrases: {
    if (gpuPercent >= 0 && gpuTemp >= 75)    return gpuHotPhrases
    if (cpuPercent >= 75)                    return cpuHotPhrases
    if (memPercent >= 75)                    return memHeavyPhrases
    if (diskPercent >= 75)                   return diskFullPhrases
    if (gpuPercent >= 60)                    return gpuBusyPhrases
    if (cpuPercent >= 40)                    return cpuBusyPhrases
    return idlePhrases
  }

  readonly property string heroPhrase: activePhrases[phraseIndex % activePhrases.length]

  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: heroLabel
      property: "opacity"
      to: 0
      duration: 120
      easing.type: Easing.InQuad
    }
    ScriptAction {
      script: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
    }
    PropertyAnimation {
      target: heroLabel
      property: "opacity"
      to: 1
      duration: 160
      easing.type: Easing.OutQuad
    }
  }
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
      else {
        root.bar.run("omarchy-launch-or-focus-tui btop")
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

          Column {
            width: parent.width - refreshButton.width - Style.spacing.rowGap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xs

            Text {
              width: parent.width
              text: "System"
              color: root.panelFg
              font.family: root.panelFont
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              id: heroLabel
              width: parent.width
              text: root.heroPhrase
              color: Qt.rgba(root.panelFg.r, root.panelFg.g, root.panelFg.b, 0.5)
              font.family: root.panelFont
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.1
              elide: Text.ElideRight
            }
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
