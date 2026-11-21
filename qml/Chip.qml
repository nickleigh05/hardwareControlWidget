// Small pill button styled like the bar's buttons.
import QtQuick

Rectangle {
    id: chip
    property string label: ""
    property bool active: false
    property color surface: "#313244"
    property color hover: "#45475a"
    property color accent: "#89b4fa"
    property color accentText: "#1e1e2e"
    property color fg: "#cdd6f4"
    property string fontFamily: "monospace"
    property real ui: 1
    property int cornerRadius: 8
    signal clicked()

    implicitWidth: Math.round(txt.implicitWidth + 22 * ui)
    implicitHeight: Math.round(28 * ui)
    radius: cornerRadius
    color: active ? accent : (area.containsMouse ? hover : surface)
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: txt
        anchors.centerIn: parent
        text: chip.label
        font.family: chip.fontFamily
        font.pixelSize: Math.round(12 * chip.ui)
        font.bold: chip.active
        color: chip.active ? chip.accentText : chip.fg
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
