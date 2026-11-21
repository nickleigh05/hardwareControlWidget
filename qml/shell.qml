// Standalone test window, run from the repo root:  quickshell -p qml/shell.qml
import QtQuick
import Quickshell

FloatingWindow {
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight
    color: "#1e1e2e"
    RgbDisplayWidget { id: panel; anchors.fill: parent; backendDir: Quickshell.shellPath("../backend") }
}
