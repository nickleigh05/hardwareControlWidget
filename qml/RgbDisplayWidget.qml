// Shell-agnostic lighting panel. Talks only to backend/rgb-ctl via argv arrays (never a shell).
// Theme is injected through properties; the defaults are Catppuccin Mocha.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    // ---- theme (adapters bind these to the host shell) ----
    property color bg: "#1e1e2e"
    property color surface: "#313244"
    property color surfaceHi: "#45475a"
    property color fg: "#cdd6f4"
    property color subfg: "#a6adc8"
    property color accent: "#89b4fa"
    property color accentText: "#1e1e2e"
    property color errorColor: "#f38ba8"
    property string fontFamily: "monospace"
    property int cornerRadius: 8
    property real ui: 1                     // UI scale factor
    property int tab: 0                     // 0 = Lighting, 1 = Display
    property bool shown: true               // host sets false while hidden (pauses polling)
    property bool framed: true              // false when the host draws the card (e.g. a popout)
    readonly property bool dragging: hueBar.dragging || valueBar.dragging || displayTab.dragging

    // ---- backend ----
    // Folder holding rgb-ctl / tryx-ctl. Default is where install.sh links them;
    // hosts can override with a real path (e.g. Quickshell.shellPath("../backend")).
    property string backendDir: (Quickshell.env("HOME") ?? "") + "/.local/bin"

    // ---- state ----
    property var devices: []
    property int target: -1                 // -1 = all devices, otherwise OpenRGB device index
    property real hue: 0                    // 0..100
    property real sat: 1                    // 0..1
    property real value: 100                // brightness 0..100 (scales the colour)
    property string status: ""
    property bool loading: true
    property var pending: null

    function s(v) { return Math.round(v * ui) }

    function hex2(n) { const h = Math.round(n * 255).toString(16); return h.length < 2 ? "0" + h : h }
    readonly property color picked: Qt.hsva(hue / 100, sat, value / 100, 1)
    function pickedHex() {
        const c = picked
        return (hex2(c.r) + hex2(c.g) + hex2(c.b)).toUpperCase()
    }

    function labelFor(d) {
        if (d.type === "DRAM") {
            let n = 0
            for (const x of devices) { if (x.type === "DRAM") { n++; if (x.index === d.index) return "RAM " + n } }
        }
        if (d.type === "GPU") return "GPU"
        if (d.type === "Motherboard") return "Board"
        return d.name
    }
    function deviceByIndex(i) { return devices.find(d => d.index === i) }

    // Modes offered for the current target (union across devices when targeting all)
    function modesForTarget() {
        let list
        if (target >= 0) {
            const d = deviceByIndex(target)
            list = d ? d.modes.slice() : []
        } else if (devices.length > 0) {
            list = []
            for (const d of devices) for (const m of d.modes) if (list.indexOf(m) < 0) list.push(m)
        } else list = []
        return list.filter(m => m !== "Direct")
    }
    function currentModeOfTarget() {
        if (target >= 0) { const d = deviceByIndex(target); return d ? d.current : "" }
        return ""
    }
    function modeActive(m) {
        if (target >= 0) return currentModeOfTarget() === m
        const have = devices.filter(d => d.modes.indexOf(m) >= 0)
        return have.length > 0 && have.every(d => d.current === m)
    }
    // Devices a mode applies to under the current target
    function devicesForMode(m) {
        if (target >= 0) return String(target)
        const ids = devices.filter(d => d.modes.indexOf(m) >= 0).map(d => d.index)
        return ids.length ? ids.join(",") : "all"
    }
    function colorModeFor() {
        const cur = currentModeOfTarget()
        return /static|breath|flash|pulse|strobe|chase|gradient|dazzle|shift/i.test(cur) ? cur : "Static"
    }
    function setLocalMode(m) {
        devices = devices.map(d => (target < 0 || d.index === target) && d.modes.indexOf(m) >= 0
            ? Object.assign({}, d, { current: m }) : d)
    }

    // ---- command plumbing: one in flight, newest queued request wins ----
    function send(args) { pending = args; if (!applyProc.running) pump() }
    function pump() {
        if (pending === null) return
        applyProc.command = [backendDir + "/rgb-ctl"].concat(pending)
        pending = null
        applyProc.running = true
    }
    function targetArg() { return target < 0 ? "all" : String(target) }

    function applyColor() { send(["apply", targetArg(), colorModeFor(), pickedHex(), "-"]); setLocalMode(colorModeFor()) }
    function applyMode(m) { send(["apply", devicesForMode(m), m, pickedHex(), "-"]); setLocalMode(m) }
    function refresh() { loading = true; if (!stateProc.running) stateProc.running = true; displayTab.refresh() }

    Process {
        id: applyProc
        stderr: StdioCollector { id: applyErr }
        onExited: (code, st) => {
            root.status = code !== 0 ? (applyErr.text.trim().split("\n")[0] || "rgb-ctl failed") : ""
            root.pump()
        }
    }
    Process {
        id: stateProc
        command: [root.backendDir + "/rgb-ctl", "state"]
        stdout: StdioCollector { id: stateOut }
        onExited: (code, st) => {
            root.loading = false
            try {
                root.devices = JSON.parse(stateOut.text)
                if (root.devices.length === 0) root.status = "No RGB devices found"
            } catch (e) { root.status = "Could not read devices" }
        }
    }
    Component.onCompleted: refresh()

    implicitWidth: s(340)
    implicitHeight: col.implicitHeight + s(32)
    radius: cornerRadius + 4
    color: framed ? bg : "transparent"
    border.width: framed ? 1 : 0
    border.color: surfaceHi

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.s(16) }
        spacing: root.s(14)

        // Header
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["Lighting", "Display"]
                delegate: Chip {
                    required property string modelData
                    required property int index
                    label: modelData
                    active: root.tab === index
                    onClicked: root.tab = index
                    surface: "transparent"; hover: root.surface; accent: root.accent; accentText: root.accentText; fg: root.fg
                    fontFamily: root.fontFamily; ui: root.ui; cornerRadius: root.cornerRadius
                }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                visible: root.tab === 0
                width: root.s(16); height: width; radius: width / 2
                color: root.picked
                border.width: 1; border.color: root.surfaceHi
            }
            Text {
                visible: root.tab === 0
                text: "#" + root.pickedHex()
                font.family: root.fontFamily; font.pixelSize: root.s(11)
                color: root.subfg
            }
        }

        ColumnLayout {
            id: lightingCol
            visible: root.tab === 0
            Layout.fillWidth: true; spacing: root.s(14)

        // Devices
        ColumnLayout {
            Layout.fillWidth: true; spacing: root.s(6)
            Text { text: "DEVICE"; font.family: root.fontFamily; font.pixelSize: root.s(10); font.bold: true; color: root.subfg; font.letterSpacing: 1 }
            Flow {
                Layout.fillWidth: true; spacing: root.s(6)
                Chip {
                    label: root.loading ? "Loading…" : "All"
                    active: root.target === -1
                    onClicked: root.target = -1
                    surface: root.surface; hover: root.surfaceHi; accent: root.accent; accentText: root.accentText; fg: root.fg
                    fontFamily: root.fontFamily; ui: root.ui; cornerRadius: root.cornerRadius
                }
                Repeater {
                    model: root.devices
                    delegate: Chip {
                        required property var modelData
                        label: root.labelFor(modelData)
                        active: root.target === modelData.index
                        onClicked: root.target = modelData.index
                        surface: root.surface; hover: root.surfaceHi; accent: root.accent; accentText: root.accentText; fg: root.fg
                        fontFamily: root.fontFamily; ui: root.ui; cornerRadius: root.cornerRadius
                    }
                }
            }
        }

        // Colour
        ColumnLayout {
            Layout.fillWidth: true; spacing: root.s(8)
            Text { text: "COLOUR"; font.family: root.fontFamily; font.pixelSize: root.s(10); font.bold: true; color: root.subfg; font.letterSpacing: 1 }
            Flow {
                Layout.fillWidth: true; spacing: root.s(8)
                Repeater {
                    model: [[0, 1], [8, 1], [16, 1], [33, 1], [50, 1], [60, 1], [75, 1], [88, 1], [0, 0]]
                    delegate: Rectangle {
                        required property var modelData
                        width: root.s(26); height: width; radius: width / 2
                        color: Qt.hsva(modelData[0] / 100, modelData[1], 1, 1)
                        border.width: 1; border.color: root.surfaceHi
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.hue = modelData[0]; root.sat = modelData[1]; root.applyColor() }
                        }
                    }
                }
            }
            BarSlider {
                id: hueBar
                Layout.fillWidth: true; hue: true; ui: root.ui
                value: root.hue; knob: root.fg
                onMoved: v => { root.hue = v; root.sat = 1; root.applyColor() }
            }
        }

        // Brightness
        ColumnLayout {
            Layout.fillWidth: true; spacing: root.s(6)
            RowLayout {
                Layout.fillWidth: true
                Text { text: "BRIGHTNESS"; font.family: root.fontFamily; font.pixelSize: root.s(10); font.bold: true; color: root.subfg; font.letterSpacing: 1; Layout.fillWidth: true }
                Text { text: Math.round(root.value) + "%"; font.family: root.fontFamily; font.pixelSize: root.s(11); color: root.subfg }
            }
            BarSlider {
                id: valueBar
                Layout.fillWidth: true; ui: root.ui
                value: root.value; track: root.surfaceHi; fill: root.accent; knob: root.fg
                onMoved: v => { root.value = v; root.applyColor() }
            }
        }

        // Modes (real list from the selected device)
        ColumnLayout {
            Layout.fillWidth: true; spacing: root.s(6)
            Text { text: "MODE"; font.family: root.fontFamily; font.pixelSize: root.s(10); font.bold: true; color: root.subfg; font.letterSpacing: 1 }
            Flow {
                Layout.fillWidth: true; spacing: root.s(6)
                Repeater {
                    model: root.modesForTarget()
                    delegate: Chip {
                        required property string modelData
                        label: modelData
                        active: root.modeActive(modelData)
                        onClicked: root.applyMode(modelData)
                        surface: root.surface; hover: root.surfaceHi; accent: root.accent; accentText: root.accentText; fg: root.fg
                        fontFamily: root.fontFamily; ui: root.ui; cornerRadius: root.cornerRadius
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.status !== "" ? root.status : "Brightness scales the colour; animated effects ignore it."
            wrapMode: Text.Wrap
            font.family: root.fontFamily; font.pixelSize: root.s(10)
            color: root.status !== "" ? root.errorColor : root.subfg
            opacity: 0.85
        }
        }   // lightingCol

        DisplayTab {
            id: displayTab
            visible: root.tab === 1
            shown: root.shown
            Layout.fillWidth: true
            backendDir: root.backendDir
            surface: root.surface; surfaceHi: root.surfaceHi; fg: root.fg; subfg: root.subfg
            accent: root.accent; accentText: root.accentText; errorColor: root.errorColor
            fontFamily: root.fontFamily; cornerRadius: root.cornerRadius; ui: root.ui
        }
    }
}
