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

  // ── Phrases ──────────────────────────────────────────────────────────────
  // Rotated in the hero subtitle while the panel is open.
  // Priority: GPU hot > CPU hot > mem heavy > disk full > GPU busy > CPU busy > idle

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

  readonly property var activePhrases: {
    if (gpuPercent >= 0 && gpuTemp >= 75) return gpuHotPhrases
    if (cpuPercent >= 75)                 return cpuHotPhrases
    if (memPercent >= 75)                 return memHeavyPhrases
    if (diskPercent >= 75)                return diskFullPhrases
    if (gpuPercent >= 60)                 return gpuBusyPhrases
    if (cpuPercent >= 40)                 return cpuBusyPhrases
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
      target: heroSubtitle
      property: "opacity"
      to: 0
      duration: 180
      easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
    }
    PropertyAnimation {
      target: heroSubtitle
      property: "opacity"
      to: 1
      duration: 260
      easing.type: Easing.InQuad
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

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
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.refresh()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // Header
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            text: "󰍛"
            color: root.panelFg
            font.family: root.panelFont
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.leftMargin: Style.space(17)
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "System"
              color: root.panelFg
              font.family: root.panelFont
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            // Rotating phrase — replaces the static CPU/Memory subtitle
            Text {
              id: heroSubtitle
              width: parent.width
              text: root.heroPhrase.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.panelFont
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
            }
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
          label: "GPU"
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

    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    Rectangle {
      id: divider
      visible: row.showDivider
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 1
      color: Qt.rgba(row.foreground.r, row.foreground.g, row.foreground.b, 0.12)
    }

    Item {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      implicitHeight: Math.max(badge.implicitHeight, labelColumn.implicitHeight, meterColumn.implicitHeight)

      Rectangle {
        id: badge
        implicitWidth: labelColumn.implicitHeight
        implicitHeight: implicitWidth
        width: implicitWidth
        height: implicitHeight
        radius: Style.cornerRadius
        color: Qt.rgba(row.accent.r, row.accent.g, row.accent.b, 0.22)
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        Text {
          anchors.centerIn: parent
          text: row.badgeText
          color: row.accent
          font.family: row.fontFamily
          font.pixelSize: Style.font.title
        }
      }

      Column {
        id: labelColumn
        anchors.left: badge.right
        anchors.leftMargin: Style.space(10)
        anchors.right: meterColumn.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

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
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Column {
        id: meterColumn
        width: Style.space(78)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

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
