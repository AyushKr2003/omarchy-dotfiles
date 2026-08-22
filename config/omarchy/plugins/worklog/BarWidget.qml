import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "worklog"

    function injectPanel() {
        var target = panelLoader.item;
        if (!target)
            return;
        if ("bar" in target)
            target.bar = root.bar;
        if ("settings" in target)
            target.settings = root.settings;
        if ("anchorItem" in target)
            target.anchorItem = button;
        if ("hostWidget" in target)
            target.hostWidget = root;
    }

    function togglePanel() {
        if (panelLoader.item && panelLoader.item.toggle)
            panelLoader.item.toggle();
    }

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

    function open() {
        if (panelLoader.item && panelLoader.item.openFromHotkey)
            panelLoader.item.openFromHotkey();
    }

    function close() {
        if (panelLoader.item && panelLoader.item.close)
            panelLoader.item.close();
    }

    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    function closeForPopoutSwitch() {
        if (panelLoader.item && panelLoader.item.closeForPopoutSwitch)
            panelLoader.item.closeForPopoutSwitch();
    }

    readonly property real openPanelIndicatorWidth: button.implicitWidth
    readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

    visible: true
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: injectPanel()
    onSettingsChanged: injectPanel()

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel();
            Qt.callLater(root.injectPanel);
        }
    }

    IpcHandler {
        target: "worklog"

        function open() { root.open() }
        function close() { root.close() }
        function show() { root.open() }
        function hide() { root.close() }
        function toggle() { root.togglePanel() }
        function quickAdd() {
            if (panelLoader.item && panelLoader.item.openQuickAdd)
                panelLoader.item.openQuickAdd();
        }
    }

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: panelLoader.item ? panelLoader.item.label : "󱃔"
        slotSize: Style.bar.statusSlot
        tooltipText: "Work log"

        onPressed: function (b) {
            if (b === Qt.RightButton) {
                if (panelLoader.item && panelLoader.item.openQuickAdd)
                    panelLoader.item.openQuickAdd();
            } else {
                root.togglePanel();
            }
        }
    }
}
