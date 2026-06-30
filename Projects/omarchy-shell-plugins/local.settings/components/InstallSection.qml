import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: installColumn.implicitHeight + Style.spacing.rowPaddingX * 2
    radius: root.cornerRadius
    color: Style.normalFillFor(root.foreground, root.accent)
    border.color: Style.normalBorderFor(root.foreground, root.accent)
    border.width: Style.normalBorderWidth

    property color foreground: Color.foreground
    property color accent: Color.accent
    property color urgent: Color.urgent
    property string fontFamily: Style.font.family
    property int cornerRadius: Style.cornerRadius

    property string installMode: "local"
    property string localPluginPath: ""
    property string localPluginStatus: ""
    property string newSourceUrl: ""
    property var sourcesList: []
    property var availablePlugins: []
    property string onlineInstallStatus: ""

    property bool installLocalBusy: false
    property bool addSourceBusy: false
    property bool refreshSourcesBusy: false
    property bool fetchAvailableBusy: false
    property bool installFromSourceBusy: false

    signal installLocalRequested(string path)
    signal browseRequested()
    signal removeSourceRequested(string name)
    signal addSourceRequested()
    signal refreshSourcesRequested()
    signal fetchAvailableRequested()
    signal installFromSourceRequested(string id)

    ColumnLayout {
        id: installColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.spacing.rowPaddingX
        anchors.rightMargin: Style.spacing.rowPaddingX
        spacing: Style.spacing.labelGap

        Text {
            text: "Install"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.labelGap

            Button {
                text: "Local"
                foreground: root.foreground
                fontFamily: root.fontFamily
                focusable: true
                bordered: root.installMode !== "local"
                selected: root.installMode === "local"
                onClicked: root.installMode = "local"
            }

            Button {
                text: "Source"
                foreground: root.foreground
                fontFamily: root.fontFamily
                focusable: true
                bordered: root.installMode !== "source"
                selected: root.installMode === "source"
                onClicked: root.installMode = "source"
            }

            Item { Layout.fillWidth: true; implicitHeight: 1 }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.installMode === "local"
            spacing: Style.spacing.labelGap

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing.rowGap

                TextField {
                    Layout.fillWidth: true
                    text: root.localPluginPath
                    placeholderText: "/path/to/plugin-folder"
                    foreground: root.foreground
                    accent: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    activeFocusOnTab: true
                    onTextEdited: root.localPluginPath = text
                    onAccepted: root.installLocalRequested(text)
                }

                Button {
                    text: "Browse"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    focusable: true
                    bordered: true
                    onClicked: root.browseRequested()
                }

                Button {
                    text: "Install"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    focusable: true
                    bordered: true
                    enabled: !root.installLocalBusy
                    onClicked: root.installLocalRequested(root.localPluginPath)
                }
            }

            Text {
                visible: root.localPluginStatus !== ""
                text: root.localPluginStatus
                color: root.localPluginStatus.indexOf("failed") !== -1 || root.localPluginStatus.indexOf("Invalid") !== -1 || root.localPluginStatus.indexOf("not") !== -1
                    ? root.urgent
                    : Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.installMode === "source"
            spacing: Style.spacing.labelGap

            Column {
                Layout.fillWidth: true
                visible: root.sourcesList.length > 0
                spacing: Style.spacing.xxs

                Repeater {
                    model: root.sourcesList
                    delegate: RowLayout {
                        required property var modelData
                        width: parent.width
                        spacing: Style.spacing.rowGap

                        Text {
                            text: (modelData.name || "") + "  ·  " + (modelData.url || "")
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.bodySmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Button {
                            text: "Remove"
                            foreground: root.urgent
                            fontFamily: root.fontFamily
                            focusable: true
                            onClicked: root.removeSourceRequested(modelData.name)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing.rowGap

                TextField {
                    Layout.fillWidth: true
                    text: root.newSourceUrl
                    placeholderText: "https://github.com/owner/omarchy-plugins.git"
                    foreground: root.foreground
                    accent: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    activeFocusOnTab: true
                    onTextEdited: root.newSourceUrl = text
                    onAccepted: root.addSourceRequested()
                }

                Button {
                    text: "Add"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    focusable: true
                    bordered: true
                    enabled: !root.addSourceBusy
                    onClicked: root.addSourceRequested()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing.rowGap

                Button {
                    text: "Refresh sources"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    focusable: true
                    bordered: true
                    enabled: !root.refreshSourcesBusy
                    onClicked: root.refreshSourcesRequested()
                }

                Button {
                    text: root.availablePlugins.length > 0 ? root.availablePlugins.length + " available" : "Available plugins"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    focusable: true
                    bordered: true
                    enabled: !root.fetchAvailableBusy
                    onClicked: root.fetchAvailableRequested()
                }

                Item { Layout.fillWidth: true; implicitHeight: 1 }
            }

            Column {
                Layout.fillWidth: true
                visible: root.availablePlugins.length > 0
                spacing: Style.spacing.xxs

                Repeater {
                    model: root.availablePlugins
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        implicitHeight: Style.space(42)
                        radius: root.cornerRadius
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.spacing.controlGap
                            anchors.rightMargin: Style.spacing.controlGap
                            spacing: Style.spacing.rowGap

                            Text {
                                text: (modelData.name || modelData.id || "") + "  ·  " + (modelData.source || "")
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.bodySmall
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.status || ""
                                color: modelData.status === "installed"
                                    ? Qt.lighter(root.accent, 1.3)
                                    : (modelData.status === "update-available" ? root.accent : Qt.darker(root.foreground, 1.5))
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                visible: modelData.status === "installed" || modelData.status === "update-available"
                            }

                            Button {
                                text: modelData.status === "installed" ? "Installed" : "Install"
                                foreground: modelData.status === "installed" ? Qt.darker(root.foreground, 1.5) : root.foreground
                                fontFamily: root.fontFamily
                                focusable: true
                                bordered: modelData.status !== "installed"
                                enabled: modelData.status !== "installed" && !root.installFromSourceBusy
                                onClicked: root.installFromSourceRequested(modelData.id)
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.sourcesList.length === 0 && root.availablePlugins.length === 0 && root.onlineInstallStatus === ""
                text: "No sources configured. Add a plugin source URL above to install plugins from remote repositories."
                color: Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Text {
                visible: root.onlineInstallStatus !== ""
                text: root.onlineInstallStatus
                color: root.onlineInstallStatus.indexOf("failed") !== -1 || root.onlineInstallStatus.indexOf("Failed") !== -1
                    ? root.urgent
                    : Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
