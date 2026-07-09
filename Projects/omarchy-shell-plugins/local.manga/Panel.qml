import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool closingFromHost: false
  property var shell: null
  property var manifest: null
  property var settings: ({})

  readonly property int configuredWidth: Math.max(560, Number(setting("windowWidth", 760)) || 760)
  readonly property int configuredHeight: Math.max(520, Number(setting("windowHeight", 820)) || 820)

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  function toggle(payloadJson) {
    if (window.visible) close()
    else open(payloadJson || "{}")
  }

  FloatingWindow {
    id: window
    title: "Manga"
    visible: false
    color: Color.background
    implicitWidth: Style.space(root.configuredWidth)
    implicitHeight: Style.space(root.configuredHeight)
    minimumSize: Qt.size(Style.space(560), Style.space(520))

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function")
        root.shell.hide((root.manifest && root.manifest.id) || "local.manga")
      if (visible) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    FocusScope {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.close()
          event.accepted = true
        }
      }

      MangaReader {
        anchors.fill: parent
      }
    }
  }
}
