import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool screenshotReady: false
  property bool busy: false
  property bool failed: false
  property string statusText: "Ready"
  property string processOutput: ""
  property string screenshotPath: ""
  property string targetLanguage: "en"
  property var annotations: []
  property string helperScript: decodeURIComponent(String(Qt.resolvedUrl("translate-screen.sh")).replace(/^file:\/\//, ""))
  readonly property var currentScreen: focusedScreen()
  readonly property string pluginId: manifest && manifest.id ? manifest.id : "local.screenTranslator"
  readonly property color foreground: Color.menu.text
  readonly property color background: Color.menu.background
  readonly property color border: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property string fontFamily: Style.font.menuFamily
  readonly property string screenName: root.currentScreen ? String(root.currentScreen.name || "") : ""

  function runtimeDir() {
    var xdg = Quickshell.env("XDG_RUNTIME_DIR")
    return xdg && xdg.length > 0 ? xdg : "/tmp"
  }

  function focusedScreen() {
    var focusedName = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
    for (var i = 0; i < Quickshell.screens.length; i++) {
      if (Quickshell.screens[i].name === focusedName) return Quickshell.screens[i]
    }
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  }

  function open(payloadJson) {
    root.opened = true
    root.screenshotReady = false
    root.busy = true
    root.failed = false
    root.processOutput = ""
    root.annotations = []
    root.statusText = "Capturing screen"
    var payload = ({})
    try { payload = payloadJson ? JSON.parse(payloadJson) : ({}) } catch (e) { payload = ({}) }
    root.targetLanguage = payload.targetLanguage || payload.target || "en"
    root.screenshotPath = root.runtimeDir() + "/omarchy-screen-translator-" + Date.now() + ".png"
    captureProc.running = true
  }

  function close() {
    root.opened = false
    root.busy = false
    root.annotations = []
    captureProc.running = false
    translateProc.running = false
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  function toggle(payloadJson) {
    if (root.opened) root.dismiss()
    else root.open(payloadJson || "{}")
  }

  function startTranslation() {
    root.busy = true
    root.failed = false
    root.statusText = "Translating"
    translateProc.running = true
  }

  function screenshotUrl() {
    return root.screenshotPath.length > 0 ? "file://" + root.screenshotPath : ""
  }

  function normalizeAnnotation(item) {
    var x = Number(item.x)
    var y = Number(item.y)
    var width = Number(item.width)
    var height = Number(item.height)
    if ((!isFinite(width) || !isFinite(height)) && item.boundingBox && item.boundingBox.vertices) {
      var vertices = item.boundingBox.vertices
      if (vertices.length >= 4) {
        x = Number(vertices[0].x)
        y = Number(vertices[0].y)
        width = Number(vertices[1].x) - x
        height = Number(vertices[3].y) - y
      }
    }
    if (!isFinite(x) || !isFinite(y) || !isFinite(width) || !isFinite(height)) return null
    var translation = String(item.translation || item.translatedText || "")
    var text = String(item.text || "")
    if (translation.length === 0 || translation === text) return null
    return {
      x: Math.max(0, x),
      y: Math.max(0, y),
      width: Math.max(Style.space(32), width),
      height: Math.max(Style.space(22), height),
      text: text,
      translation: translation
    }
  }

  function applyAnnotations(raw) {
    var parsed = []
    try { parsed = JSON.parse(raw || "[]") } catch (e) { parsed = [] }
    if (!Array.isArray(parsed)) parsed = []
    var next = []
    for (var i = 0; i < parsed.length; i++) {
      var normalized = normalizeAnnotation(parsed[i])
      if (normalized) next.push(normalized)
    }
    root.annotations = next
  }

  IpcHandler {
    target: "local.screenTranslator"
    function open(): void { root.open("{}") }
    function close(): void { root.dismiss() }
    function toggle(): void { root.toggle("{}") }
    function translate(): void { root.open("{}") }
    function translateTo(target: string): void { root.open(JSON.stringify({ targetLanguage: target })) }
  }

  Process {
    id: captureProc
    running: false
    command: [
      "bash",
      "-lc",
      "mkdir -p " + Util.shellQuote(root.runtimeDir())
        + " && grim " + (root.screenName.length > 0 ? "-o " + Util.shellQuote(root.screenName) + " " : "")
        + " " + Util.shellQuote(root.screenshotPath)
    ]
    onExited: function(code) {
      if (!root.opened) return
      if (code === 0) {
        root.screenshotReady = true
        root.startTranslation()
      } else {
        root.busy = false
        root.failed = true
        root.statusText = "Screenshot failed"
        root.annotations = [{
          x: Style.space(40),
          y: Style.space(40),
          width: Style.space(620),
          height: Style.space(120),
          text: "",
          translation: "Could not capture the focused monitor. Make sure `grim` is installed and Wayland screen capture is available."
        }]
      }
    }
  }

  Process {
    id: translateProc
    running: false
    command: ["bash", root.helperScript, root.screenshotPath, root.targetLanguage]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.processOutput = text.trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim().length > 0) root.processOutput = text.trim()
    }
    onExited: function(code) {
      if (!root.opened) return
      root.busy = false
      root.failed = code !== 0
      if (code === 0) {
        root.applyAnnotations(root.processOutput)
        root.statusText = root.annotations.length > 0 ? "Translated" : "No non-English text"
      } else {
        root.statusText = "Translation failed"
        root.annotations = [{
          x: Style.space(40),
          y: Style.space(40),
          width: Style.space(560),
          height: Style.space(120),
          text: "",
          translation: root.processOutput.length > 0 ? root.processOutput : "Translator command failed."
        }]
      }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    screen: root.currentScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "local-screen-translator"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    Image {
      id: screenshotImage
      anchors.fill: parent
      source: root.screenshotReady ? root.screenshotUrl() : ""
      fillMode: Image.PreserveAspectCrop
      visible: false
    }

    Item {
      id: blurMask
      anchors.fill: parent
      layer.enabled: true
      visible: false

      Repeater {
        model: root.annotations
        delegate: Rectangle {
          required property var modelData
          x: modelData.x - Style.space(4)
          y: modelData.y - Style.space(3)
          width: modelData.width + Style.space(8)
          height: modelData.height + Style.space(6)
          radius: Style.cornerRadius
        }
      }
    }

    MultiEffect {
      anchors.fill: parent
      source: screenshotImage
      maskEnabled: true
      maskSource: blurMask
      blurEnabled: true
      blur: 1
      blurMax: 48
      opacity: root.screenshotReady && root.annotations.length > 0 ? 1 : 0
    }

    Repeater {
      model: root.annotations
      delegate: Rectangle {
        required property var modelData
        x: modelData.x - Style.space(4)
        y: modelData.y - Style.space(3)
        width: modelData.width + Style.space(8)
        height: modelData.height + Style.space(6)
        radius: Style.cornerRadius
        color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.62)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
        border.width: 1

        Text {
          anchors.fill: parent
          anchors.margins: Style.space(4)
          text: parent.modelData.translation
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Math.max(Style.font.caption, Math.min(Style.font.body, parent.height * 0.38))
          font.bold: true
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
          maximumLineCount: Math.max(1, Math.floor(height / Math.max(1, font.pixelSize)))
        }
      }
    }

    Rectangle {
      visible: root.busy || root.failed
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.leftMargin: Style.gapsOut
      anchors.topMargin: Style.gapsOut
      implicitWidth: statusRow.implicitWidth + Style.spacing.controlPaddingX * 2
      implicitHeight: statusRow.implicitHeight + Style.spacing.controlPaddingY * 2
      radius: Style.cornerRadius
      color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.78)
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
      border.width: 1

      Row {
        id: statusRow
        anchors.centerIn: parent
        spacing: Style.spacing.controlGap

        Text {
          text: root.busy ? "󰔟" : (root.failed ? "󰅙" : "󰗊")
          color: root.failed ? Color.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.icon
        }

        Text {
          text: root.statusText
          color: root.failed ? Color.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
        }
      }
    }
}
