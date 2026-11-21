import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

// Bar button that toggles the RGB popout.
Item {
    id: root

    property var module: null
    property var widget: module
    readonly property var activeTarget: widget || module

    property string orientation: (activeTarget && activeTarget.orientation !== undefined) ? activeTarget.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? Boolean(activeTarget.isPreview) : false
    readonly property bool isRightBar: barWindow ? (barWindow.barPosition === "right") : false
    readonly property bool isBottomBar: barWindow ? (barWindow.barPosition === "bottom") : false

    function s(val) {
        if (barWindow && typeof barWindow.cs === "function") return barWindow.cs(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    readonly property real pillSize: s(root.isCompact ? 28 : 30)

    property real targetLength: {
        if (module && !module.moduleActive) return 0;
        return pillSize + s(root.isCompact ? 8 : 10);
    }
    property bool isFaceVisible: targetLength > 0

    function syncImplicitSize() {
        let cross = module ? module.thickness : (parent ? (isVertical ? parent.width : parent.height) : 0);
        implicitWidth = isVertical ? cross : targetLength;
        implicitHeight = isVertical ? targetLength : cross;
    }
    onTargetLengthChanged: syncImplicitSize()
    onIsVerticalChanged: syncImplicitSize()
    onModuleChanged: syncImplicitSize()
    onParentChanged: syncImplicitSize()
    Timer { running: true; interval: 0; onTriggered: root.syncImplicitSize() }

    function anchorArgs() {
        let pt = btn.mapToItem(null, 0, 0);
        let scr = (barWindow && barWindow.screen) ? barWindow.screen : null;
        let x = isVertical ? (isRightBar ? pt.x : pt.x + btn.width) : (pt.x + btn.width / 2);
        let y = isVertical ? (pt.y + btn.height / 2) : (isBottomBar ? pt.y : pt.y + btn.height);
        return [scr, x, y, isVertical && isRightBar, !isVertical && isBottomBar, isVertical];
    }

    ClickButton {
        id: btn
        anchors.centerIn: parent
        width: root.pillSize
        height: root.pillSize
        horizontalPadding: 0
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - root.s(2))
        buttonIcon: "󰌶"
        iconFontSize: root.s(root.isCompact ? 14 : 15)
        accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.subtext0
        action_highlight: RgbController.isVisible
        onClicked: {
            if (root.isPreview) return;
            let a = root.anchorArgs();
            RgbController.toggle(a[0], a[1], a[2], a[3], a[4], a[5]);
        }
    }
}
