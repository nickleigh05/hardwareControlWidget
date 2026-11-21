pragma Singleton
import QtQuick
import Quickshell

// Open/close state + anchor position for the RGB popout (same contract as SideMusicController).
Item {
    id: controller

    property bool isVisible: false
    property real targetX: 0
    property real targetY: 0
    property bool alignRight: false
    property bool alignBottom: false
    property bool isSideBar: false
    property var screen: null
    property bool menuHovered: false
    property bool busy: false           // e.g. a slider is being dragged: never auto-hide
    property int hoveredItems: 0

    Timer {
        id: hideTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (!controller.menuHovered && !controller.busy && controller.hoveredItems <= 0)
                controller.isVisible = false;
        }
    }

    function itemEntered(scr, posX, posY, isRight, isBottom, isSide) {
        hoveredItems++;
        hideTimer.stop();
        show(scr, posX, posY, isRight, isBottom, isSide);
    }
    function itemExited() {
        hoveredItems = Math.max(0, hoveredItems - 1);
        if (hoveredItems <= 0 && !menuHovered) requestHide();
    }
    function show(scr, posX, posY, isRight, isBottom, isSide) {
        hideTimer.stop();
        screen = scr; targetX = posX; targetY = posY;
        alignRight = isRight; alignBottom = isBottom; isSideBar = isSide;
        isVisible = true;
    }
    function hide() { hideTimer.stop(); hoveredItems = 0; isVisible = false; }
    function requestHide() { if (!menuHovered && !busy && hoveredItems <= 0) hideTimer.restart(); }
    function cancelHide() { hideTimer.stop(); }
    function toggle(scr, posX, posY, isRight, isBottom, isSide) {
        if (isVisible) hide(); else show(scr, posX, posY, isRight, isBottom, isSide);
    }
}
