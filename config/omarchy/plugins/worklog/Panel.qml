import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
    id: root
    moduleName: "worklog"
    ipcTarget: "worklog"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    readonly property var barIdentity: hostWidget || root
    readonly property string label: "󱃔"
    property int total: 0
    property int doneCount: 0
    property int inProgressCount: 0

    // Content theme accessors guarded against null bar
    readonly property color contentForeground: bar ? bar.barForeground : Color.foreground
    readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

    // Detail state (transitions inline inside the bar panel)
    property int detailIndex: -1
    property bool detailOpen: false
    property bool quickAddOpen: false

    // Vim-style list cursor + filtering
    property int cursorIndex: 0
    property string filterText: ""

    // Export state
    readonly property string exportDir: Quickshell.env("HOME") + "/Work/worklog_plugin"
    readonly property string exportPath: exportDir + "/work.txt"
    property string exportStatus: ""

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/settings"
    readonly property string historyPath: stateDir + "/worklog.history.json"

    // Source of truth (persisted); `viewModel` is the filtered display list.
    ListModel {
        id: entryModel
    }
    ListModel {
        id: viewModel
    }

    function openFromHotkey() {
        root.controller.show();
        Qt.callLater(function () {
            if (root.opened)
                root.setCenterHoverRevealSuppressed(true);
        });
    }

    function close() {
        closeDetail();
        closeQuickAdd();
        clearFilter();
        setCenterHoverRevealSuppressed(false);
        root.controller.hide();
    }

    function toggle() {
        if (root.opened)
            root.close();
        else
            root.openFromHotkey();
    }

    function closeForPopoutSwitch() {
        root.close();
    }

    function openQuickAdd() {
        root.quickAddOpen = true;
        Qt.callLater(function () {
            if (root.quickAddOpen) {
                quickAddField.forceActiveFocus();
                quickAddField.selectAll();
            }
        });
    }

    function closeQuickAdd() {
        root.quickAddOpen = false;
        quickAddField.clear();
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.barIdentity, direction);
        return false;
    }

    function setCenterHoverRevealSuppressed(value) {
        if (root.bar && "centerHoverRevealSuppressed" in root.bar)
            root.bar.centerHoverRevealSuppressed = value;
    }

    function recount() {
        total = entryModel.count;
        var done = 0;
        var inProg = 0;
        for (var i = 0; i < entryModel.count; ++i) {
            var st = entryModel.get(i).status;
            if (st === "done") done++;
            else if (st === "in-progress") inProg++;
        }
        doneCount = done;
        inProgressCount = inProg;
    }

    function matches(item) {
        if (root.filterText === "")
            return true;
        var needle = root.filterText.toLowerCase();
        return String(item.title).toLowerCase().indexOf(needle) >= 0
            || String(item.body).toLowerCase().indexOf(needle) >= 0;
    }

    function rebuildView() {
        viewModel.clear();
        for (var i = 0; i < entryModel.count; ++i) {
            var item = entryModel.get(i);
            if (root.matches(item)) {
                viewModel.append({
                    title: item.title,
                    body: item.body,
                    date: item.date,
                    status: item.status,
                    modelIndex: i
                });
            }
        }
        root.clampCursor();
    }

    function clampCursor() {
        if (viewModel.count === 0)
            root.cursorIndex = -1;
        else if (root.cursorIndex >= viewModel.count)
            root.cursorIndex = viewModel.count - 1;
        else if (root.cursorIndex < 0)
            root.cursorIndex = 0;
        Qt.callLater(function () {
            if (entryList && viewModel.count > 0 && root.cursorIndex >= 0)
                entryList.positionViewAtIndex(root.cursorIndex, ListView.Contain);
        });
    }

    function loadEntries(raw) {
        var entries = Model.parseEntries(raw);
        entryModel.clear();
        for (var i = 0; i < entries.length; ++i)
            entryModel.append(entries[i]);
        recount();
        root.rebuildView();
    }

    function saveEntries() {
        var entries = [];
        for (var i = 0; i < entryModel.count; ++i) {
            var item = entryModel.get(i);
            entries.push({
                title: item.title,
                body: item.body,
                date: item.date,
                status: item.status
            });
        }
        historyFile.setText(JSON.stringify(entries, null, 2) + "\n");
    }

    function exportEntries() {
        if (entryModel.count === 0) {
            root.exportStatus = "Nothing to export";
            return;
        }
        var lines = [];
        for (var i = 0; i < entryModel.count; ++i) {
            var item = entryModel.get(i);
            var date = String(Model.formatDate(item.date)).replace(/\|/g, "\\|");
            var title = String(item.title).replace(/\|/g, "\\|");
            var body = String(item.body).replace(/\n|\r/g, " ").replace(/\|/g, "\\|");
            lines.push(date + " | " + title + " | " + body);
        }
        exportFile.setText(lines.join("\n") + "\n");
        root.exportStatus = "Exported " + entryModel.count + (entryModel.count === 1 ? " entry" : " entries");
        statusResetTimer.restart();
    }

    Timer {
        id: statusResetTimer
        interval: 4000
        repeat: false
        onTriggered: root.exportStatus = ""
    }

    function addEntryTitle(text) {
        var title = String(text).replace(/^\s+|\s+$/g, "");
        if (title === "")
            return false;
        entryModel.insert(0, {
            title: title,
            body: "",
            date: Model.nowISO(),
            status: "todo"
        });
        saveEntries();
        recount();
        root.rebuildView();
        root.cursorIndex = 0;
        return true;
    }

    function cycleStatus(modelIndex) {
        if (modelIndex < 0 || modelIndex >= entryModel.count)
            return;
        var order = ["todo", "in-progress", "done"];
        var cur = entryModel.get(modelIndex).status;
        var next = order[(order.indexOf(cur) + 1) % order.length];
        entryModel.setProperty(modelIndex, "status", next);
        saveEntries();
        recount();
        root.rebuildView();
    }

    function openDetail(modelIndex) {
        if (modelIndex < 0 || modelIndex >= entryModel.count)
            return;
        root.detailIndex = modelIndex;
        var item = entryModel.get(modelIndex);
        detailTitleField.text = item.title;
        detailBodyEdit.text = item.body;
        detailStatus.value = item.status;
        detailDateLabel.text = Model.formatDate(item.date);
        root.detailOpen = true;
        root.cursorFollowDetail();
        Qt.callLater(function () {
            if (root.detailOpen)
                detailKeys.forceActiveFocus();
        });
    }

    function cursorFollowDetail() {
        for (var i = 0; i < viewModel.count; i++) {
            if (viewModel.get(i).modelIndex === root.detailIndex) {
                root.cursorIndex = i;
                if (entryList)
                    entryList.positionViewAtIndex(i, ListView.Contain);
                return;
            }
        }
    }

    function closeDetail() {
        root.detailOpen = false;
        root.detailIndex = -1;
        Qt.callLater(function () {
            keyCatcher.forceActiveFocus();
        });
    }

    function persistDetail() {
        var title = String(detailTitleField.text).replace(/^\s+|\s+$/g, "");
        if (title === "")
            return false;
        if (root.detailIndex < 0) {
            entryModel.insert(0, {
                title: title,
                body: detailBodyEdit.text,
                date: Model.nowISO(),
                status: detailStatus.value
            });
            root.detailIndex = 0;
            saveEntries();
            recount();
            root.rebuildView();
            return true;
        }
        var index = root.detailIndex;
        if (index < 0 || index >= entryModel.count)
            return false;
        entryModel.setProperty(index, "title", title);
        entryModel.setProperty(index, "body", detailBodyEdit.text);
        entryModel.setProperty(index, "status", detailStatus.value);
        saveEntries();
        recount();
        root.rebuildView();
        return true;
    }

    function saveDetail() {
        if (root.persistDetail())
            root.closeDetail();
    }

    function detailNavigate(delta) {
        if (entryModel.count === 0)
            return;
        root.persistDetail();
        if (root.detailIndex < 0)
            return;
        var next = root.detailIndex + delta;
        if (next < 0)
            next = 0;
        else if (next >= entryModel.count)
            next = entryModel.count - 1;
        if (next !== root.detailIndex)
            root.openDetail(next);
    }

    function detailSaveNext() {
        if (entryModel.count === 0)
            return;
        root.persistDetail();
        if (root.detailIndex < 0)
            return;
        var next = root.detailIndex + 1;
        if (next >= entryModel.count) {
            root.closeDetail();
            Qt.callLater(function () {
                keyCatcher.forceActiveFocus();
            });
        } else {
            root.openDetail(next);
        }
    }

    function detailBack() {
        root.closeDetail();
        Qt.callLater(function () {
            keyCatcher.forceActiveFocus();
        });
    }

    function detailTextKey(t) {
        if (t === "a" || t === "A" || t === "i" || t === "I" || t === "o" || t === "O") {
            detailTitleField.forceActiveFocus();
            detailTitleField.selectAll();
        } else if (t === "e" || t === "E") {
            detailBodyEdit.forceActiveFocus();
        } else if (t === "q" || t === "Q") {
            root.closeDetail();
        }
    }

    function detailTab() {
        if (detailTitleField.activeFocus)
            detailBodyEdit.forceActiveFocus();
        else if (detailBodyEdit.activeFocus)
            detailStatus.forceActiveFocus();
        else
            detailTitleField.forceActiveFocus();
    }

    function deleteDetail() {
        var index = root.detailIndex;
        if (index < 0) {
            root.closeDetail();
            Qt.callLater(function () {
                keyCatcher.forceActiveFocus();
            });
            return;
        }
        root.closeDetail();
        root.removeEntry(index);
    }

    function removeEntry(modelIndex) {
        if (modelIndex < 0 || modelIndex >= entryModel.count)
            return;
        entryModel.remove(modelIndex);
        saveEntries();
        recount();
        root.rebuildView();
    }

    // ---- vim-style cursor commands ----
    function moveCursor(delta) {
        if (viewModel.count === 0)
            return;
        var next = root.cursorIndex + delta;
        if (next < 0)
            next = 0;
        else if (next >= viewModel.count)
            next = viewModel.count - 1;
        root.cursorIndex = next;
        entryList.positionViewAtIndex(root.cursorIndex, ListView.Contain);
    }

    function cursorToTop() {
        if (viewModel.count === 0)
            return;
        root.cursorIndex = 0;
        entryList.positionViewAtIndex(0, ListView.Contain);
    }

    function cursorToBottom() {
        if (viewModel.count === 0)
            return;
        root.cursorIndex = viewModel.count - 1;
        entryList.positionViewAtIndex(root.cursorIndex, ListView.Contain);
    }

    function cursorModelIndex() {
        if (root.cursorIndex < 0 || root.cursorIndex >= viewModel.count)
            return -1;
        return viewModel.get(root.cursorIndex).modelIndex;
    }

    function cursorStatus() {
        var mi = root.cursorModelIndex();
        if (mi < 0)
            return;
        root.cycleStatus(mi);
    }

    function cursorDelete() {
        var mi = root.cursorModelIndex();
        if (mi < 0)
            return;
        root.removeEntry(mi);
        root.clampCursor();
    }

    function cursorOpen() {
        var mi = root.cursorModelIndex();
        if (mi < 0)
            return;
        root.openDetail(mi);
    }

    function focusFilterField() {
        filterField.forceActiveFocus();
        filterField.selectAll();
    }

    function clearFilter() {
        root.filterText = "";
        filterField.clear();
        root.rebuildView();
        Qt.callLater(function () {
            keyCatcher.forceActiveFocus();
        });
    }

    function openNewDetail() {
        root.detailIndex = -1;
        detailTitleField.text = "";
        detailBodyEdit.text = "";
        detailStatus.value = "todo";
        detailDateLabel.text = "New entry";
        root.detailOpen = true;
        Qt.callLater(function () {
            if (root.detailOpen) {
                detailTitleField.forceActiveFocus();
                detailTitleField.selectAll();
            }
        });
    }

    function handleTextKey(t) {
        if (t === "c" || t === "C") root.cursorStatus();
        else if (t === "a" || t === "A" || t === "i" || t === "o" || t === "I" || t === "O") root.openNewDetail();
        else if (t === "g") root.cursorToTop();
        else if (t === "G") root.cursorToBottom();
        else if (t === "/") root.focusFilterField();
        else if (t === "e" || t === "E") root.exportEntries();
        else if (t === "q" || t === "Q") root.close();
    }

    function statusGlyph(status) {
        if (status === "done") return "󰄲";
        if (status === "in-progress") return "󰔟";
        return "󰄱";
    }

    function statusColor(status) {
        if (status === "done") return Color.accent;
        if (status === "in-progress") return Color.accent;
        return Qt.darker(root.contentForeground, 1.6);
    }

    FileView {
        id: historyFile
        path: root.historyPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadEntries(text())
        onLoadFailed: root.loadEntries("[]")
        onFileChanged: reload()
    }

    Process {
        id: ensureDirsProc
        command: ["mkdir", "-p", root.stateDir, root.exportDir]
        onExited: historyFile.reload()
    }

    FileView {
        id: exportFile
        path: root.exportPath
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        ensureDirsProc.running = true;
    }

    GlobalShortcut {
        appid: "worklog"
        name: "quick-add"
        onPressed: root.openQuickAdd()
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        centerOnBar: false
        focusTarget: root.detailOpen ? detailKeys : keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(420))
        contentHeight: panel.fittedContentHeight(root.detailOpen ? detailColumn.implicitHeight : todoColumn.implicitHeight)

        // ═══════════════════════════════════════════════════════════════
        // VIEW 1: TASK LIST VIEW (INLINE IN BAR POPUP)
        // ═══════════════════════════════════════════════════════════════
        PanelKeyCatcher {
            id: keyCatcher
            visible: !root.detailOpen
            anchors.fill: parent
            blocked: filterField.activeFocus || root.detailOpen
            onCloseRequested: root.close()
            onTabRequested: function (direction) {
                root.switchPanel(direction);
            }
            onMoveRequested: function (dx, dy) {
                if (dy !== 0) root.moveCursor(dy);
                else if (dx > 0) root.openDetail(root.cursorModelIndex());
                else if (dx < 0) root.focusFilterField();
            }
            onActivateRequested: root.cursorOpen()
            onReturnRequested: root.cursorOpen()
            onDeleteRequested: root.cursorDelete()
            onTextKey: root.handleTextKey(text)

            Column {
                id: todoColumn
                anchors.fill: parent
                spacing: Style.space(12)

                // Header section
                Item {
                    width: parent.width
                    height: Math.max(headerLeftRow.implicitHeight, headerRightRow.implicitHeight)

                    Row {
                        id: headerLeftRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(10)

                        Text {
                            text: root.label
                            color: Color.accent
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.display
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            spacing: Style.space(2)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "WORK LOG"
                                color: root.contentForeground
                                font.family: root.contentFontFamily
                                font.pixelSize: Style.font.title
                                font.bold: true
                            }

                            Text {
                                text: root.total + (root.total === 1 ? " entry" : " entries")
                                color: Qt.darker(root.contentForeground, 1.5)
                                font.family: root.contentFontFamily
                                font.pixelSize: Style.font.bodySmall
                            }
                        }
                    }

                    Row {
                        id: headerRightRow
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(6)

                        PanelActionButton {
                            iconText: "󰐕"
                            tooltipText: "Add entry (a)"
                            foreground: root.contentForeground
                            hoverColor: Color.accent
                            fontFamily: root.contentFontFamily
                            onClicked: root.openNewDetail()
                        }

                        PanelActionButton {
                            iconText: "󱁍"
                            tooltipText: "Export log (e)"
                            foreground: root.contentForeground
                            hoverColor: Color.accent
                            fontFamily: root.contentFontFamily
                            onClicked: root.exportEntries()
                        }
                    }
                }

                // Filter / Search Bar (fully responsive, non-overflowing)
                Item {
                    width: parent.width
                    height: filterField.implicitHeight

                    TextField {
                        id: filterField
                        anchors.left: parent.left
                        anchors.right: clearFilterButton.visible ? clearFilterButton.left : parent.right
                        anchors.rightMargin: clearFilterButton.visible ? Style.spacing.controlGap : 0
                        anchors.verticalCenter: parent.verticalCenter
                        placeholderText: "Filter entries… (/)"
                        foreground: root.contentForeground
                        font.family: root.contentFontFamily
                        text: root.filterText
                        onTextChanged: {
                            root.filterText = filterField.text;
                            root.rebuildView();
                        }

                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.clearFilter();
                                root.cursorToTop();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.clearFilter();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                root.switchPanel(event.key === Qt.Key_Backtab ? -1 : 1);
                                event.accepted = true;
                            }
                        }
                    }

                    PanelActionButton {
                        id: clearFilterButton
                        visible: root.filterText !== ""
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        iconText: "󰅖"
                        tooltipText: "Clear filter (Esc)"
                        foreground: root.contentForeground
                        hoverColor: Color.accent
                        fontFamily: root.contentFontFamily
                        onClicked: root.clearFilter()
                    }
                }

                // Export Status Notification Toast
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.exportStatus
                    color: Color.accent
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.italic: true
                    visible: root.exportStatus !== ""
                }

                PanelSeparator {
                    width: parent.width
                    foreground: root.contentForeground
                }

                // Main Entry List
                ListView {
                    id: entryList
                    width: parent.width
                    height: Math.min(Style.space(320), Math.max(Style.space(48), viewModel.count * (Style.space(52) + Style.space(4))))
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    model: viewModel
                    spacing: Style.space(4)

                    delegate: CursorSurface {
                        id: entryRow
                        required property int index
                        required property string title
                        required property string body
                        required property string date
                        required property string status
                        required property int modelIndex

                        readonly property bool hasBody: body !== ""
                        readonly property bool cursorOn: root.cursorIndex === index
                        readonly property bool isDone: status === "done"

                        hasCursor: cursorOn
                        current: status === "in-progress"
                        foreground: root.contentForeground
                        accent: Color.accent

                        width: entryList.width
                        height: Style.space(52)

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(10)
                            anchors.rightMargin: Style.space(44)
                            spacing: Style.space(12)

                            Text {
                                text: root.statusGlyph(status)
                                color: root.statusColor(status)
                                font.family: root.contentFontFamily
                                font.pixelSize: Style.font.iconLarge
                                anchors.verticalCenter: parent.verticalCenter

                                MouseArea {
                                    id: statusArea
                                    anchors.fill: parent
                                    anchors.margins: -Style.space(6)
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cycleStatus(modelIndex)
                                    PanelToolTip {
                                        visible: statusArea.containsMouse
                                        text: status === "done" ? "Done · click to set to todo"
                                            : status === "in-progress" ? "In progress · click to mark done"
                                            : "Todo · click to mark in progress"
                                        fontFamily: root.contentFontFamily
                                    }
                                }
                            }

                            Column {
                                width: parent.width - Style.space(36)
                                spacing: Style.space(2)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    width: parent.width
                                    text: title
                                    color: isDone ? Qt.darker(root.contentForeground, 1.6) : root.contentForeground
                                    font.family: root.contentFontFamily
                                    font.pixelSize: Style.font.body
                                    font.bold: status === "in-progress" || cursorOn
                                    elide: Text.ElideRight
                                }

                                Row {
                                    spacing: Style.space(8)

                                    Text {
                                        text: Model.formatDate(date)
                                        color: Qt.darker(root.contentForeground, 1.7)
                                        font.family: root.contentFontFamily
                                        font.pixelSize: Style.font.bodySmall
                                    }

                                    Text {
                                        visible: hasBody
                                        text: "󰽏 notes"
                                        color: Qt.darker(root.contentForeground, 1.5)
                                        font.family: root.contentFontFamily
                                        font.pixelSize: Style.font.caption
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(4)
                            z: 10

                            PanelActionButton {
                                iconText: "󰆴"
                                tooltipText: "Delete entry (x)"
                                foreground: Qt.darker(root.contentForeground, 1.4)
                                hoverColor: Color.urgent
                                fontFamily: root.contentFontFamily
                                onClicked: root.removeEntry(modelIndex)
                            }
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            anchors.rightMargin: Style.space(44)
                            z: -1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openDetail(modelIndex)
                            onEntered: root.cursorIndex = index
                        }
                    }
                }

                // Empty state view
                Column {
                    visible: viewModel.count === 0
                    width: parent.width
                    spacing: Style.space(6)
                    topPadding: Style.space(16)
                    bottomPadding: Style.space(16)

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.filterText === "" ? "󰈙" : "󰍉"
                        color: Qt.darker(root.contentForeground, 1.8)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.display
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.filterText === "" ? "No work logged yet — press a to add an entry" : "No matching entries"
                        color: Qt.darker(root.contentForeground, 1.5)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        font.italic: true
                    }
                }

                PanelSeparator {
                    width: parent.width
                    foreground: root.contentForeground
                }

                // Cheatsheet Footer
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "j/k move · Enter open · c status · x del · / filter · a add"
                    color: Qt.darker(root.contentForeground, 1.7)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.italic: true
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // VIEW 2: INLINE DETAIL & EDIT VIEW (INLINE IN BAR POPUP)
        // ═══════════════════════════════════════════════════════════════
        PanelKeyCatcher {
            id: detailKeys
            visible: root.detailOpen
            anchors.fill: parent
            blocked: detailTitleField.activeFocus || detailBodyEdit.activeFocus || detailStatus.activeFocus
            onCloseRequested: root.closeDetail()
            onDeleteRequested: root.deleteDetail()
            onTabRequested: root.detailTab()
            onActivateRequested: detailTitleField.forceActiveFocus()
            onMoveRequested: function (dx, dy) {
                if (dy !== 0) root.detailNavigate(dy);
                else if (dx > 0) root.detailSaveNext();
                else if (dx < 0) root.detailBack();
            }
            onTextKey: root.detailTextKey(text)

            Column {
                id: detailColumn
                anchors.fill: parent
                spacing: Style.space(12)

                // Header with Back, Title, and Delete
                Item {
                    width: parent.width
                    height: Math.max(detailBackRow.implicitHeight, detailDeleteBtn.implicitHeight)

                    Row {
                        id: detailBackRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(10)

                        PanelActionButton {
                            iconText: "󰅁"
                            tooltipText: "Back to list (Esc / h)"
                            foreground: root.contentForeground
                            hoverColor: Color.accent
                            fontFamily: root.contentFontFamily
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: root.closeDetail()
                        }

                        Column {
                            spacing: Style.space(2)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: root.detailIndex < 0 ? "NEW ENTRY" : "EDIT ENTRY"
                                color: root.contentForeground
                                font.family: root.contentFontFamily
                                font.pixelSize: Style.font.title
                                font.bold: true
                            }
                            Text {
                                id: detailDateLabel
                                text: ""
                                color: Qt.darker(root.contentForeground, 1.5)
                                font.family: root.contentFontFamily
                                font.pixelSize: Style.font.bodySmall
                            }
                        }
                    }

                    PanelActionButton {
                        id: detailDeleteBtn
                        visible: root.detailIndex >= 0
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        iconText: "󰆴"
                        tooltipText: "Delete entry (x)"
                        foreground: Qt.darker(root.contentForeground, 1.4)
                        hoverColor: Color.urgent
                        fontFamily: root.contentFontFamily
                        onClicked: root.deleteDetail()
                    }
                }

                PanelSeparator {
                    width: parent.width
                    foreground: root.contentForeground
                }

                // Title Input Field
                TextField {
                    id: detailTitleField
                    width: parent.width
                    placeholderText: "Title"
                    foreground: root.contentForeground
                    font.family: root.contentFontFamily

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Tab) {
                            detailBodyEdit.forceActiveFocus();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.saveDetail();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.closeDetail();
                            event.accepted = true;
                        }
                    }
                }

                // Status Selector
                ButtonGroup {
                    id: detailStatus
                    options: [
                        { value: "todo", label: "Todo", icon: "󰄱" },
                        { value: "in-progress", label: "In progress", icon: "󰔟" },
                        { value: "done", label: "Done", icon: "󰄲" }
                    ]
                    value: "todo"
                    foreground: root.contentForeground
                    background: Color.popups.background
                    accent: Color.accent
                    fontFamily: root.contentFontFamily
                    focusable: true
                    onChanged: function (v) {
                        detailStatus.value = v;
                    }
                }

                // Notes Header
                Text {
                    text: "NOTES"
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                }

                // Notes Editor Box
                BorderSurface {
                    width: parent.width
                    height: Style.space(160)
                    radius: Style.cornerRadius
                    color: Style.controlFill(detailBodyEdit.activeFocus, false, root.contentForeground, Color.accent)
                    borderSpec: Border.controlSpec(detailBodyEdit.activeFocus ? "focus" : "normal", root.contentForeground, Color.accent)
                    clip: true

                    Flickable {
                        id: bodyScroll
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        contentWidth: width
                        contentHeight: detailBodyEdit.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height

                        TextEdit {
                            id: detailBodyEdit
                            width: bodyScroll.width
                            height: detailBodyEdit.implicitHeight
                            text: ""
                            color: root.contentForeground
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.body
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere

                            Keys.onPressed: function (event) {
                                if (event.modifiers & Qt.ControlModifier
                                        && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    root.saveDetail();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.closeDetail();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Add notes or details here…"
                        color: Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        visible: detailBodyEdit.text === ""
                    }
                }

                PanelSeparator {
                    width: parent.width
                    foreground: root.contentForeground
                }

                // Cheatsheet & Action Buttons
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "j/k prev · l next · h back · a title · e notes · x del · q close"
                    color: Qt.darker(root.contentForeground, 1.7)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.italic: true
                }

                Item {
                    width: parent.width
                    height: Math.max(deleteButton.implicitHeight, saveButton.implicitHeight)

                    Button {
                        id: deleteButton
                        anchors.left: parent.left
                        text: "󰅁  Back"
                        iconText: ""
                        bordered: true
                        background: Color.popups.background
                        foreground: root.contentForeground
                        accent: Color.accent
                        fontFamily: root.contentFontFamily
                        onClicked: root.closeDetail()
                    }

                    Button {
                        id: saveButton
                        anchors.right: parent.right
                        text: "Save & Close"
                        iconText: "󰄲"
                        bordered: true
                        background: Color.popups.background
                        foreground: root.contentForeground
                        accent: Color.accent
                        fontFamily: root.contentFontFamily
                        onClicked: root.saveDetail()
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SPOTLIGHT QUICK ADD (FOR GLOBAL SYSTEM HOTKEY SUMMONING)
    // ═══════════════════════════════════════════════════════════════
    PanelWindow {
        id: quickAddWindow
        screen: (root.bar && root.bar.screen) ? root.bar.screen : (Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        visible: root.quickAddOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "worklog-quick-add"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Rectangle {
            anchors.fill: parent
            color: Color.menu.scrim

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeQuickAdd()
            }

            BorderSurface {
                id: quickAddCard
                anchors.centerIn: parent
                width: Math.min(parent.width - Style.space(48), Style.space(460))
                height: quickAddContent.implicitHeight + quickAddCard.contentTopInset + quickAddCard.contentBottomInset
                radius: Style.cornerRadius
                color: Color.popups.background
                borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Style.normalBorderWidth)
                padding: Style.space(20)

                Item {
                    id: quickAddContent
                    anchors.fill: parent
                    anchors.topMargin: quickAddCard.contentTopInset
                    anchors.leftMargin: quickAddCard.contentLeftInset
                    anchors.rightMargin: quickAddCard.contentRightInset
                    anchors.bottomMargin: quickAddCard.contentBottomInset
                    implicitHeight: quickAddColumn.implicitHeight

                    Column {
                        id: quickAddColumn
                        width: parent.width
                        spacing: Style.space(12)

                        Text {
                            text: "QUICK ADD"
                            color: root.contentForeground
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.title
                            font.bold: true
                        }

                        TextField {
                            id: quickAddField
                            width: parent.width
                            placeholderText: "Add an entry…"
                            foreground: root.contentForeground
                            font.family: root.contentFontFamily

                            Keys.onPressed: function (event) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (root.addEntryTitle(text)) {
                                        var idx = 0;
                                        root.closeQuickAdd();
                                        root.openFromHotkey();
                                        root.openDetail(idx);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.closeQuickAdd();
                                    event.accepted = true;
                                }
                            }
                        }

                        Text {
                            text: "Enter to add · Esc to close"
                            color: Qt.darker(root.contentForeground, 1.5)
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.bodySmall
                        }
                    }
                }
            }
        }
    }

    // Retain layer-shell declaration namespace for backwards compatibility contracts
    // WlrLayershell.namespace: "worklog-detail"
}