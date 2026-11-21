import QtQuick
import Quickshell
import Quickshell.Wayland
import "../reusables"
import "../"
import "../rgbpanel"

// Popout hosting the portable RgbDisplayWidget in a card styled like the music popout.
PanelWindow {
    id: popout

    screen: RgbController.screen

    WlrLayershell.namespace: "rgbpanel"
    WlrLayershell.layer: WlrLayer.Top
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region {
        item: (popout.isVisible || card.animProgress > 0.001) ? card : null
    }

    anchors { top: true; bottom: true; left: true; right: true }

    function s(val) { return (typeof Scaler !== "undefined") ? Scaler.s(val) : val; }

    property bool isVisible: RgbController.isVisible
    property real targetX: RgbController.targetX
    property real targetY: RgbController.targetY
    property bool alignRight: RgbController.alignRight
    property bool alignBottom: RgbController.alignBottom
    property bool isSideBar: RgbController.isSideBar

    property int configRevision: 0
    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { RgbController.hide(); popout.configRevision++; }
    }

    property string barStyle: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "modular";
        let st = Config.rawSettings.bar.style;
        if (typeof st === "string") return st;
        if (st && typeof st === "object") {
            if (st.fill || st.mode === "fill") return "fill";
            if (st.solid || st.mode === "solid") return "solid";
        }
        return "modular";
    }
    onBarStyleChanged: RgbController.hide()

    property bool isSolid: barStyle === "solid" || barStyle === "fill"
    property real barHeight: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height) ? s(Config.rawSettings.bar.height) : s(40);
    }
    property real cornerRadius: ThemeBackend.borderRadius || s(12)
    property real menuMargin: isSolid ? 0 : s(8)

    visible: isVisible || card.animProgress > 0.001

    property real menuWidth: panel.implicitWidth + s(8)
    property real menuHeight: panel.implicitHeight + s(8)

    property real clampedX: {
        let w = menuWidth;
        let x = isSideBar ? (alignRight ? (targetX - w - menuMargin) : (targetX + menuMargin)) : (targetX - w / 2);
        let edge = s(8);
        return Math.max(edge, Math.min(popout.width - w - edge, x));
    }
    property real clampedY: {
        let h = menuHeight;
        let y;
        if (isSideBar) y = targetY - h / 2;
        else if (alignBottom) y = targetY - h - menuMargin;
        else y = targetY + menuMargin;
        let edge = s(8);
        return Math.max(edge, Math.min(popout.height - h - edge, y));
    }

    Item {
        id: card

        property real animProgress: popout.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation { duration: popout.isVisible ? 280 : 220; easing.type: Easing.OutCubic }
        }

        x: popout.clampedX
        y: {
            let slide = popout.s(16) * (1.0 - animProgress);
            if (popout.isSideBar) return popout.clampedY;
            return popout.alignBottom ? popout.clampedY + slide : popout.clampedY - slide;
        }
        width: popout.menuWidth
        height: popout.menuHeight
        opacity: animProgress
        scale: 0.92 + 0.08 * animProgress
        transformOrigin: popout.isSideBar ? (popout.alignRight ? Item.Right : Item.Left)
                                          : (popout.alignBottom ? Item.Bottom : Item.Top)

        Rectangle {
            id: cardBox
            anchors.fill: parent
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            radius: popout.cornerRadius
            border.width: 0
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                rim: 0
            }

            HoverHandler {
                onHoveredChanged: {
                    RgbController.menuHovered = hovered;
                    if (hovered) RgbController.cancelHide(); else RgbController.requestHide();
                }
            }
            MouseArea { anchors.fill: parent; preventStealing: true }

            RgbDisplayWidget {
                id: panel
                x: popout.s(4); y: popout.s(4)
                width: popout.s(340)
                framed: false
                shown: popout.isVisible
                ui: popout.s(1)
                backendDir: (Quickshell.env("HOME") ?? "") + "/.local/bin"

                bg: ThemeBackend.base
                surface: ThemeBackend.surface0
                surfaceHi: ThemeBackend.surface1
                fg: ThemeBackend.text
                subfg: ThemeBackend.subtext0
                accent: ThemeBackend.mauve
                accentText: ThemeBackend.crust
                errorColor: ThemeBackend.red
                fontFamily: ThemeBackend.fontFamily
                cornerRadius: ThemeBackend.borderRadius

                onDraggingChanged: {
                    RgbController.busy = dragging;
                    if (dragging) RgbController.cancelHide(); else RgbController.requestHide();
                }
            }
        }
    }

    // Refresh device state each time the popout opens
    onIsVisibleChanged: if (isVisible) panel.refresh()
}
