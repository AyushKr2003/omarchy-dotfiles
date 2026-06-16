pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color verm:   "#c0442b"
    readonly property color cream:  "#e6d6cb"
    readonly property color bright: "#fff6f0"
    readonly property color dim:    "#8a7d74"
    readonly property string font:  "Inter"

    readonly property color fieldBg: Qt.rgba(1, 0.96, 0.94, 0.10)
    readonly property color fieldBorder: Qt.rgba(230 / 255, 214 / 255, 203 / 255, 0.30)
    readonly property color trackBg: Qt.rgba(240 / 255, 224 / 255, 215 / 255, 0.16)
    readonly property color error:  "#e0563b"
}
