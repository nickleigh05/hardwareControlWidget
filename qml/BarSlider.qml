// Horizontal slider. Set `hue: true` for a rainbow track (value 0-100 maps to hue 0-1).
import QtQuick

Item {
    id: sl
    property real value: 100            // 0..100
    property bool hue: false
    property color track: "#45475a"
    property color fill: "#89b4fa"
    property color knob: "#cdd6f4"
    property real ui: 1
    readonly property bool dragging: area.pressed
    signal moved(real v)                // while dragging
    signal committed(real v)            // on release

    implicitHeight: Math.round(22 * ui)

    Rectangle {
        id: bar
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Math.round(8 * sl.ui)
        radius: height / 2
        color: sl.track
        gradient: sl.hue ? rainbow : null

        Rectangle {
            visible: !sl.hue
            width: Math.max(bar.height, bar.width * sl.value / 100)
            height: bar.height
            radius: bar.radius
            color: sl.fill
        }
    }
    Gradient {
        id: rainbow
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0;   color: "#ff0000" }
        GradientStop { position: 0.167; color: "#ffff00" }
        GradientStop { position: 0.333; color: "#00ff00" }
        GradientStop { position: 0.5;   color: "#00ffff" }
        GradientStop { position: 0.667; color: "#0000ff" }
        GradientStop { position: 0.833; color: "#ff00ff" }
        GradientStop { position: 1.0;   color: "#ff0000" }
    }
    Rectangle {
        width: Math.round(16 * sl.ui); height: width; radius: width / 2
        color: sl.knob
        border.width: 2; border.color: sl.hue ? Qt.hsla(sl.value / 100, 1, 0.5, 1) : sl.fill
        anchors.verticalCenter: parent.verticalCenter
        x: (sl.width - width) * sl.value / 100
    }
    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function pick(mx) {
            const w = sl.width - Math.round(16 * sl.ui)
            sl.value = Math.max(0, Math.min(100, (mx - Math.round(8 * sl.ui)) / w * 100))
            sl.moved(sl.value)
        }
        onPressed: mouse => pick(mouse.x)
        onPositionChanged: mouse => { if (pressed) pick(mouse.x) }
        onReleased: sl.committed(sl.value)
    }
}
