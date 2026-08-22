import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui
import "ManualModel.js" as ManualModel

// Reader window for the Omarchy manual and installed 3rd-party plugin
// documentation. Summon with `omarchy launch manual [chapter]`, or directly via:
//   omarchy-shell shell summon omarchy.manual "{}"
// or for a specific plugin:
//   omarchy-shell shell summon omarchy.manual '{"plugin":"local.manga"}'
//
// Qt renders the markdown itself. Standalone image paragraphs are split out
// by ManualModel.splitBlocks and drawn as width-fitted Image items, because
// QTextDocument draws images at their natural size and the screenshots
// are wider than any comfortable reading column.
Item {
  id: root

  // ---- host injections ----------------------------------------------------
  property var shell: null
  property var pluginRegistry: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property string userHome: Quickshell.env("HOME")

  // ---- source model -------------------------------------------------------
  property var sources: []
  property int currentSourceIndex: -1
  property string pendingSourceRef: ""
  property string pendingCustomDir: ""

  readonly property string manualDir: (currentSourceIndex >= 0 && currentSourceIndex < sources.length)
    ? sources[currentSourceIndex].dir : ""
  readonly property string currentSourceName: (currentSourceIndex >= 0 && currentSourceIndex < sources.length)
    ? sources[currentSourceIndex].name : "Manual"
  readonly property string currentSourceId: (currentSourceIndex >= 0 && currentSourceIndex < sources.length)
    ? sources[currentSourceIndex].id : ""

  readonly property var sourceOptions: {
    var opts = []
    for (var i = 0; i < sources.length; i++) {
      opts.push({
        value: sources[i].id,
        label: sources[i].name + (sources[i].isCore ? " (Omarchy)" : "")
      })
    }
    return opts
  }

  function selectSource(index) {
    if (index < 0 || index >= sources.length || index === currentSourceIndex) return
    currentSourceIndex = index
    searchField.text = ""
    rescanChapters()
  }

  // ---- plugin lifecycle ---------------------------------------------------
  property bool closingFromHost: false

  function open(payloadJson) {
    closingFromHost = false

    var requestedChapter = ""
    var requestedSource = ""
    var requestedDir = ""

    if (payloadJson) {
      try {
        var parsed = JSON.parse(String(payloadJson))
        if (parsed && typeof parsed === "object") {
          if (typeof parsed.chapter === "string") requestedChapter = parsed.chapter
          if (typeof parsed.plugin === "string") requestedSource = parsed.plugin
          else if (typeof parsed.pluginId === "string") requestedSource = parsed.pluginId
          else if (typeof parsed.source === "string") requestedSource = parsed.source
          if (typeof parsed.dir === "string") requestedDir = parsed.dir
          else if (typeof parsed.path === "string") requestedDir = parsed.path
        }
      } catch (e) { /* ignore */ }
    }

    pendingChapterRef = requestedChapter
    pendingSourceRef = requestedSource
    pendingCustomDir = requestedDir

    discoverProcess.running = false
    discoverProcess.running = true

    window.visible = true
    Qt.callLater(function() { keyScope.forceActiveFocus() })
  }

  // Host-initiated close (`shell hide`). Visibility flips without notifying
  // the host back — it already knows.
  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  // User-initiated close (Esc, window close button). Tell the shell so its
  // openPanelIds map stays consistent and `toggle` works on the next call.
  function requestClose() {
    if (shell && typeof shell.hide === "function") {
      shell.hide("shadow.manual")
      shell.hide("omarchy.manual")
    } else {
      window.visible = false
    }
  }

  // ---- discover sources ---------------------------------------------------
  readonly property string discoverScript:
    "omarchy_path=\"$1\"; home_dir=\"$2\"; " +
    "core_dir=\"\"; " +
    "for p in \"$omarchy_path/manual\" \"$home_dir/.config/omarchy/manual\" \"$home_dir/omarchy-dotfiles/omarchy-repo/manual\" \"/usr/share/doc/omarchy/manual\"; do " +
    "  if [ -d \"$p\" ] && compgen -G \"$p/*.md\" >/dev/null; then core_dir=\"$p\"; break; fi; " +
    "done; " +
    "if [ -n \"$core_dir\" ]; then printf 'core\\t%s\\t%s\\t%s\\n' 'omarchy.manual' \"$core_dir\" 'Omarchy Manual'; fi; " +
    "pdir=\"$home_dir/.config/omarchy/plugins\"; " +
    "if [ -d \"$pdir\" ]; then " +
    "  for sub in \"$pdir\"/*/; do " +
    "    [ -d \"$sub\" ] || continue; " +
    "    base=\"${sub%/}\"; base=\"${base##*/}\"; " +
    "    [ \"$base\" != \"manual\" ] && [ \"$base\" != \"shadow.manual\" ] || continue; " +
    "    if compgen -G \"$sub/*.md\" >/dev/null || compgen -G \"$sub/docs/*.md\" >/dev/null; then " +
    "      name=\"$base\"; " +
    "      if [ -f \"$sub/manifest.json\" ]; then " +
    "        mname=$(jq -r '.name // empty' \"$sub/manifest.json\" 2>/dev/null); " +
    "        [ -n \"$mname\" ] && name=\"$mname\"; " +
    "      fi; " +
    "      printf 'plugin\\t%s\\t%s\\t%s\\n' \"$base\" \"$sub\" \"$name\"; " +
    "    fi; " +
    "  done; " +
    "fi"

  Process {
    id: discoverProcess
    running: false
    command: ["bash", "-c", root.discoverScript, "--", root.omarchyPath, root.userHome]
    stdout: StdioCollector { id: discoverStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var lines = String(discoverStdout.text || "").split("\n")
      var list = []
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line) continue
        var parts = line.split("\t")
        if (parts.length < 3) continue
        var kind = parts[0]
        var id = parts[1]
        var dir = parts[2].replace(/\/$/, "")
        var name = parts.length >= 4 ? parts[3] : id
        list.push({
          id: id,
          dirName: id,
          dir: dir,
          name: name,
          isCore: (kind === "core")
        })
      }

      if (root.pendingCustomDir) {
        var customDir = root.pendingCustomDir.replace(/\/$/, "")
        var foundCustom = -1
        for (var c = 0; c < list.length; c++) {
          if (list[c].dir === customDir) { foundCustom = c; break }
        }
        if (foundCustom === -1) {
          list.unshift({
            id: "custom",
            dirName: "custom",
            dir: customDir,
            name: "Documentation",
            isCore: false
          })
        }
      }

      root.sources = list

      var wantedSource = root.pendingSourceRef
      root.pendingSourceRef = ""
      var sIdx = -1
      if (wantedSource) {
        sIdx = ManualModel.resolveSource(root.sources, wantedSource)
      }
      if (sIdx < 0 && root.pendingCustomDir) {
        sIdx = 0
      }
      root.pendingCustomDir = ""

      if (sIdx < 0) sIdx = root.currentSourceIndex
      if (sIdx < 0 || sIdx >= root.sources.length) sIdx = 0

      root.currentSourceIndex = sIdx
      root.rescanChapters()
    }
  }

  // ---- chapter model ------------------------------------------------------
  property var chapters: []
  property int currentIndex: -1
  property string pendingChapterRef: ""
  property var blocks: []

  function selectChapter(index) {
    if (index < 0 || index >= chapters.length) return
    currentIndex = index
  }

  function stepChapter(delta) {
    selectChapter(currentIndex + delta)
  }

  function rescanChapters() {
    scanProcess.running = false
    if (!manualDir) {
      chapters = []
      currentIndex = -1
      return
    }
    scanProcess.command = ["bash", "-c", root.scanScript, "--", root.manualDir]
    scanProcess.running = true
  }

  // One "filename\ttitle" line per chapter, title being the first `# `
  // heading so the sidebar shows real titles, not slug reconstructions.
  // Supports root *.md files and docs/*.md files.
  readonly property string scanScript:
    "dir=\"$1\"; [ -d \"$dir\" ] || exit 0; " +
    "for f in \"$dir\"/*.md; do " +
    "  [ -f \"$f\" ] || continue; " +
    "  title=$(awk '/^# /{sub(/^# +/, \"\"); print; exit}' \"$f\"); " +
    "  printf '%s\\t%s\\n' \"${f#$dir/}\" \"$title\"; " +
    "done; " +
    "if [ -d \"$dir/docs\" ]; then " +
    "  for f in \"$dir/docs\"/*.md; do " +
    "    [ -f \"$f\" ] || continue; " +
    "    title=$(awk '/^# /{sub(/^# +/, \"\"); print; exit}' \"$f\"); " +
    "    printf '%s\\t%s\\n' \"${f#$dir/}\" \"$title\"; " +
    "  done; " +
    "fi"

  Process {
    id: scanProcess
    running: false
    command: ["bash", "-c", root.scanScript, "--", root.manualDir]
    stdout: StdioCollector { id: scanStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.chapters = ManualModel.parseChapterIndex(scanStdout.text)
      var wanted = root.pendingChapterRef
      root.pendingChapterRef = ""
      var index = wanted ? ManualModel.resolveChapter(root.chapters, wanted) : -1
      if (index < 0) index = 0
      root.currentIndex = Math.max(0, Math.min(root.chapters.length - 1, index))
    }
  }

  FileView {
    id: chapterFile
    path: root.currentIndex >= 0 && root.currentIndex < root.chapters.length && root.manualDir !== ""
      ? root.manualDir + "/" + root.chapters[root.currentIndex].file
      : ""
    watchChanges: false
    printErrors: false
    onLoaded: {
      root.blocks = ManualModel.splitBlocks(text(), root.markdownTheme())
      if (root.pendingScrollLine > 0) {
        var line = root.pendingScrollLine
        root.pendingScrollLine = 0
        root.scrollToLine(line)
      } else {
        reader.contentY = 0
      }
    }
    onLoadFailed: root.blocks = []
  }

  function markdownTheme() {
    return ManualModel.themeFor(String(Color.accent), String(Color.foreground),
      String(Color.background), String(Color.muted))
  }

  // Theme colors are baked into each block's anchors, chips, and code
  // highlights, so a theme switch while the reader is open has to re-derive
  // the blocks.
  Connections {
    target: Color
    function onAccentChanged() {
      if (chapterFile.path) root.blocks = ManualModel.splitBlocks(chapterFile.text(), root.markdownTheme())
    }
  }

  function openLink(link) {
    var target = ManualModel.linkTarget(link)
    if (target.kind === "external") Qt.openUrlExternally(target.url)
    else if (target.kind === "chapter") {
      var index = ManualModel.resolveChapter(root.chapters, target.file)
      if (index >= 0) root.selectChapter(index)
    }
  }

  // ---- search -------------------------------------------------------------
  property var searchResults: []
  property int searchIndex: 0
  property int pendingScrollLine: 0
  property int highlightIndex: -1

  function runSearch() {
    searchProcess.running = false
    if (!sidebar.searching || !manualDir) {
      searchResults = []
      searchIndex = 0
      return
    }
    searchProcess.command = ["grep", "-rinF", "--include=*.md", "-m", "5", "-e", searchField.text.trim(), manualDir]
    searchProcess.running = true
  }

  function jumpToResult(index) {
    if (index < 0 || index >= searchResults.length) return
    searchIndex = index
    var result = searchResults[index]
    if (currentIndex === result.chapterIndex) {
      scrollToLine(result.line)
    } else {
      pendingScrollLine = result.line
      currentIndex = result.chapterIndex
    }
  }

  // Scroll the reading pane so the block holding the given source line sits
  // near the top, and flash it. Deferred so the block column has been laid
  // out when the target's position is read.
  function scrollToLine(line) {
    var index = ManualModel.blockIndexForLine(blocks, line)
    if (index < 0) return
    highlightIndex = index
    highlightClear.restart()
    Qt.callLater(function() {
      var item = blockRepeater.itemAt(index)
      if (!item) return
      var maxY = Math.max(0, reader.contentHeight - reader.height)
      reader.contentY = Math.max(0, Math.min(maxY, item.y - 32))
    })
  }

  Process {
    id: searchProcess
    running: false
    command: []
    stdout: StdioCollector { id: searchStdout; waitForEnd: true }
    onExited: {
      root.searchResults = ManualModel.parseSearchResults(searchStdout.text, root.chapters, 50)
      root.searchIndex = 0
    }
  }

  Timer {
    id: searchTimer
    interval: 250
    onTriggered: root.runSearch()
  }

  Timer {
    id: highlightClear
    interval: 1800
    onTriggered: root.highlightIndex = -1
  }

  // ---- window -------------------------------------------------------------
  FloatingWindow {
    id: window
    title: root.currentSourceName ? (root.currentSourceName + (root.currentSourceName.indexOf("Manual") === -1 ? " — Manual" : "")) : "Manual"
    color: Color.background
    implicitWidth: 1080
    implicitHeight: 800
    minimumSize: Qt.size(720, 480)

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function") {
        root.shell.hide("shadow.manual")
        root.shell.hide("omarchy.manual")
      }
    }

    FocusScope {
      id: keyScope
      anchors.fill: parent
      focus: true

      function scrollBy(dy) {
        if (reader.contentHeight <= reader.height) return
        reader.contentY = Math.max(0, Math.min(reader.contentHeight - reader.height, reader.contentY + dy))
      }

      // Keys bubble up here from the read-only text blocks, so scrolling
      // keeps working after a click into the prose to select something.
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) scrollBy(90)
        else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) scrollBy(-90)
        else if (event.key === Qt.Key_D || event.key === Qt.Key_PageDown || event.key === Qt.Key_Space) scrollBy(reader.height * 0.85)
        else if (event.key === Qt.Key_U || event.key === Qt.Key_PageUp) scrollBy(-reader.height * 0.85)
        else if (event.key === Qt.Key_Home) reader.contentY = 0
        else if (event.key === Qt.Key_End) reader.contentY = Math.max(0, reader.contentHeight - reader.height)
        else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) root.stepChapter(-1)
        else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) root.stepChapter(1)
        else if (event.key === Qt.Key_Slash) {
          searchField.forceActiveFocus()
          searchField.selectAll()
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) root.requestClose()
        else return
        event.accepted = true
      }

      // ---- sidebar --------------------------------------------------------
      Rectangle {
        id: sidebar
        width: Math.round(250 * Style.fontScale)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        color: Util.alpha(Color.foreground, 0.04)

        // Two or more characters keeps single keystrokes from grepping the
        // whole manual for one letter.
        readonly property bool searching: searchField.text.trim().length >= 2

        Column {
          id: sidebarHeader
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 10
          spacing: 8

          Ui.Dropdown {
            id: sourceDropdown
            width: parent.width
            visible: root.sources.length > 1
            showLabel: false
            value: root.currentSourceId
            options: root.sourceOptions
            onChanged: function(val) {
              var idx = ManualModel.resolveSource(root.sources, val)
              if (idx >= 0) root.selectSource(idx)
            }
          }

          Ui.TextField {
            id: searchField
            width: parent.width
            placeholderText: "Search  ( / )"
            onTextChanged: searchTimer.restart()

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Down) {
                root.searchIndex = Math.min(root.searchIndex + 1, root.searchResults.length - 1)
              } else if (event.key === Qt.Key_Up) {
                root.searchIndex = Math.max(root.searchIndex - 1, 0)
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.jumpToResult(root.searchIndex)
              } else if (event.key === Qt.Key_Escape) {
                text = ""
                keyScope.forceActiveFocus()
              } else {
                return
              }
              event.accepted = true
            }
          }
        }

        Text {
          anchors.top: sidebarHeader.bottom
          anchors.topMargin: 16
          anchors.horizontalCenter: parent.horizontalCenter
          visible: sidebar.searching && root.searchResults.length === 0 && !searchProcess.running
          text: "No matches"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        ListView {
          id: chapterList
          anchors.top: sidebarHeader.bottom
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: 10
          anchors.bottomMargin: 10
          clip: true
          model: sidebar.searching ? root.searchResults : root.chapters
          currentIndex: sidebar.searching ? root.searchIndex : root.currentIndex
          highlightFollowsCurrentItem: true
          highlightMoveDuration: 0
          onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
          ScrollBar.vertical: ScrollBar { }

          delegate: Rectangle {
            required property var modelData
            required property int index

            readonly property bool current: index === chapterList.currentIndex

            width: chapterList.width
            height: rowColumn.implicitHeight + 12
            color: current ? Color.menu.selectedBackground : "transparent"

            Column {
              id: rowColumn
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 14
              anchors.rightMargin: 10
              spacing: 2

              Text {
                width: parent.width
                text: modelData.title
                color: current ? Color.menu.selectedText : Util.alpha(Color.foreground, 0.8)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                visible: sidebar.searching && (modelData.snippet || "").length > 0
                text: modelData.snippet || ""
                color: Util.alpha(Color.foreground, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              onClicked: sidebar.searching ? root.jumpToResult(parent.index) : root.selectChapter(parent.index)
            }
          }
        }
      }

      Rectangle {
        id: divider
        width: 1
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: sidebar.right
        color: Util.alpha(Color.foreground, 0.12)
      }

      // ---- reading pane ---------------------------------------------------
      Flickable {
        id: reader
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: divider.right
        anchors.right: parent.right
        clip: true
        contentWidth: width
        contentHeight: content.height
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { }

        Column {
          id: content
          readonly property int sideMargin: 36
          // Blocks are paragraphs, so the Column's spacing is the paragraph
          // gap Qt's markdown rendering doesn't provide on its own.
          readonly property int paragraphGap: Math.round(Style.font.body * 0.9)
          readonly property int headingGap: Math.round(Style.font.body * 1.4)
          width: Math.min(Math.round(700 * Style.fontScale), reader.width - 2 * sideMargin)
          x: Math.round((reader.width - width) / 2)
          topPadding: 28
          bottomPadding: 48
          spacing: paragraphGap

          Repeater {
            id: blockRepeater
            model: root.blocks

            delegate: Loader {
              required property var modelData
              required property int index

              width: content.width
              sourceComponent: modelData.kind === "image" ? imageBlock
                : modelData.kind === "code" ? codeBlock : textBlock

              // Flash behind the block a search jump landed on.
              Rectangle {
                z: -1
                anchors.fill: parent
                anchors.margins: -8
                radius: 6
                color: Util.alpha(Color.accent, 0.12)
                opacity: index === root.highlightIndex ? 1 : 0

                Behavior on opacity {
                  NumberAnimation { duration: 350 }
                }
              }

              Component {
                id: textBlock

                // Headings open a section, so they get extra air above —
                // except the chapter title at the very top.
                Item {
                  readonly property int gapAbove: modelData.heading && index > 0 ? content.headingGap : 0
                  width: content.width
                  height: prose.height + gapAbove

                  TextEdit {
                    id: prose
                    anchors.bottom: parent.bottom
                    width: content.width
                    text: modelData.text
                    textFormat: TextEdit.MarkdownText
                    baseUrl: "file://" + root.manualDir + "/"
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Color.foreground
                    selectionColor: Util.alpha(Color.accent, 0.45)
                    selectedTextColor: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    onLinkActivated: function(link) { root.openLink(link) }

                    HoverHandler {
                      enabled: prose.hoveredLink !== ""
                      cursorShape: Qt.PointingHandCursor
                    }
                  }
                }
              }

              Component {
                id: codeBlock

                // Fenced code in its own panel: tinted, token-highlighted,
                // and horizontally scrollable, since terminal transcripts in
                // the manual run far wider than the reading column.
                Rectangle {
                  width: content.width
                  height: codeFlick.height + 24
                  radius: 6
                  color: Util.alpha(Color.foreground, 0.05)
                  border.color: Util.alpha(Color.foreground, 0.12)
                  border.width: 1

                  Flickable {
                    id: codeFlick
                    x: 14
                    y: 12
                    width: parent.width - 28
                    height: codeText.height
                    contentWidth: codeText.width
                    contentHeight: codeText.height
                    flickableDirection: Flickable.HorizontalFlick
                    interactive: contentWidth > width
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    ScrollBar.horizontal: ScrollBar { }

                    TextEdit {
                      id: codeText
                      text: modelData.html
                      textFormat: TextEdit.RichText
                      readOnly: true
                      selectByMouse: true
                      color: Color.foreground
                      selectionColor: Util.alpha(Color.accent, 0.45)
                      selectedTextColor: Color.foreground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                    }
                  }
                }
              }

              Component {
                id: imageBlock

                Item {
                  width: content.width
                  height: figure.height + content.paragraphGap

                  Image {
                    id: figure
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    source: {
                      var src = String(modelData.source || "")
                      if (src.indexOf("://") !== -1) return src
                      if (src.charAt(0) === "/") return "file://" + src
                      return "file://" + root.manualDir + "/" + src
                    }
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    width: sourceSize.width > 0 ? Math.min(content.width, sourceSize.width) : content.width
                    height: sourceSize.width > 0 ? Math.round(width * sourceSize.height / sourceSize.width) : 0
                  }

                  Rectangle {
                    anchors.fill: figure
                    visible: figure.status === Image.Ready
                    color: "transparent"
                    border.color: Util.alpha(Color.foreground, 0.15)
                    border.width: 1
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
