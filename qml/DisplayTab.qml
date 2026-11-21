// TRYX Panorama display controls: pick media, brightness, keepalive. Talks only to backend/tryx-ctl.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: tab

    // theme (bound by RgbDisplayWidget)
    property color surface: "#313244"
    property color surfaceHi: "#45475a"
    property color fg: "#cdd6f4"
    property color subfg: "#a6adc8"
    property color accent: "#89b4fa"
    property color accentText: "#1e1e2e"
    property color errorColor: "#f38ba8"
    property string fontFamily: "monospace"
    property int cornerRadius: 8
    property real ui: 1
    property string backendDir: ""
    property bool shown: true            // host sets false while hidden, to pause polling

    readonly property bool dragging: brightBar.dragging
    function s(v) { return Math.round(v * ui) }

    // state
    property var files: []
    property string current: ""          // currently displayed file (full screen = first entry)
    property string thumbDir: ""
    property real brightness: 75
    property string daemon: "unknown"
    property bool busy: false
    property string status: ""
    property var pending: null
    property bool loaded: false
    property string dropDir: ""
    property var owned: []
    property string confirmName: ""      // tile currently asking "delete?"
    property bool syncing: false
    property bool slowSync: false
    property bool chain: false          // true when a sync was started by refresh(): continue to thumbs+state

    spacing: s(14)

    // ---- backend plumbing: one command in flight, newest queued request wins ----
    function send(args, label) { pending = { args: args, label: label || "" }; if (!cmdProc.running) pump() }
    function pump() {
        if (pending === null) return
        const p = pending; pending = null
        busy = true
        status = p.label
        cmdProc.command = [backendDir + "/tryx-ctl"].concat(p.args)
        cmdProc.running = true
    }
    // refresh = sync the drop folder, then thumbnails, then state
    function refresh() {
        if (syncProc.running || thumbProc.running || stateProc.running) return
        chain = true
        syncProc.running = true
    }

    function isGif(n) { return /\.gif$/i.test(n) }
    // reed-tpse records a displayed .gif as .mp4; map that back to the real file on the device
    function resolveCurrent(n) {
        if (files.indexOf(n) >= 0) return n
        const g = n.replace(/\.mp4$/i, ".gif")
        return files.indexOf(g) >= 0 ? g : n
    }
    function play(name) {
        if (isGif(name)) { status = "GIFs can't be shown directly. Convert to MP4 first."; return }
        current = name
        send(["display", String(Math.round(brightness)), "2:1", name], "Applying…")
    }
    function requestDelete(name) {
        if (name === current) { status = "Can't delete the video that's playing. Pick another first."; return }
        if (owned.indexOf(name) >= 0) { status = "That one came from your drop folder. Delete it there."; return }
        confirmName = name
    }
    function confirmDelete() {
        const n = confirmName; confirmName = ""
        send(["delete", n], "Deleting…")
    }
    function setBrightness(v) { send(["brightness", String(Math.round(v))], "Setting brightness…") }
    function toggleDaemon() { send([daemon === "active" ? "daemon-stop" : "daemon-start"], "Working…") }

    Process {
        id: cmdProc
        stdout: StdioCollector { id: cmdOut }
        stderr: StdioCollector { id: cmdErr }
        onExited: (code, st) => {
            tab.busy = false
            if (code !== 0) tab.status = (cmdErr.text.trim().split("\n")[0] || cmdOut.text.trim().split("\n").pop() || "tryx-ctl failed")
            else tab.status = ""
            if (tab.pending !== null) tab.pump(); else if (!stateProc.running) stateProc.running = true
        }
    }
    Process {
        id: syncProc
        command: [tab.backendDir + "/tryx-ctl", "sync"]
        stdout: StdioCollector { id: syncOut }
        onRunningChanged: {
            tab.syncing = running
            if (running) slowTimer.restart(); else { slowTimer.stop(); tab.slowSync = false }
        }
        onExited: (code, st) => {
            let changed = tab.chain
            try {
                const r = JSON.parse(syncOut.text)
                if ((r.added && r.added.length) || (r.removed && r.removed.length)) changed = true
                if (r.errors && r.errors.length) tab.status = r.errors[0]
                else if (r.pending > 0) tab.status = "Waiting for a file to finish copying…"
                else if (tab.status.indexOf("finish copying") >= 0 || tab.status.indexOf("not connected") >= 0) tab.status = ""
            } catch (e) { if (code !== 0) tab.status = "Sync failed" }
            tab.chain = false
            if (changed) thumbProc.running = true
        }
    }
    Timer { id: slowTimer; interval: 700; onTriggered: tab.slowSync = true }
    // Pick up newly dropped files while the tab is open
    Timer {
        interval: 4000; repeat: true
        running: tab.shown && tab.visible
        onTriggered: if (!syncProc.running && !cmdProc.running && !thumbProc.running && !stateProc.running) syncProc.running = true
    }
    // thumbnails first (cached, fast after the first run), then state
    Process {
        id: thumbProc
        command: [tab.backendDir + "/tryx-ctl", "thumbs"]
        onExited: stateProc.running = true
    }
    Process {
        id: stateProc
        command: [tab.backendDir + "/tryx-ctl", "state"]
        stdout: StdioCollector { id: stateOut }
        onExited: (code, st) => {
            try {
                const d = JSON.parse(stateOut.text)
                tab.files = d.files
                tab.thumbDir = d.thumbDir
                tab.dropDir = d.dropDir || ""
                tab.owned = d.owned || []
                tab.daemon = d.daemon
                if (d.current && d.current.length > 0) tab.current = tab.resolveCurrent(d.current[0])
                if (d.brightness !== null && d.brightness !== undefined && !brightBar.dragging) tab.brightness = d.brightness
                tab.loaded = true
                if (!d.connected) tab.status = "Cooler not detected"
            } catch (e) { tab.status = "Could not read display state" }
        }
    }
    Component.onCompleted: refresh()

    function tilde(p) {
        const h = Quickshell.env("HOME") || ""
        return h !== "" && p.indexOf(h + "/") === 0 ? "~" + p.slice(h.length) : p
    }
    function thumbUrl(name) { return "file://" + encodeURI(thumbDir + "/" + name + ".jpg") }
    function shortName(n) { return n.replace(/\.[^.]+$/, "") }

    // ---- UI ----
    // Now playing
    ColumnLayout {
        Layout.fillWidth: true; spacing: tab.s(6)
        Text { text: "NOW PLAYING"; font.family: tab.fontFamily; font.pixelSize: tab.s(10); font.bold: true; color: tab.subfg; font.letterSpacing: 1 }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: width / 2
            radius: tab.cornerRadius
            color: tab.surface
            clip: true
            Image {
                anchors.fill: parent
                source: tab.current !== "" && tab.thumbDir !== "" ? tab.thumbUrl(tab.current) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: tab.busy ? 0.55 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            Text {
                anchors.centerIn: parent
                visible: tab.current === ""
                text: tab.loaded ? "Nothing selected" : "Loading…"
                font.family: tab.fontFamily; font.pixelSize: tab.s(12); color: tab.subfg
            }
        }
    }

    // Media grid
    ColumnLayout {
        Layout.fillWidth: true; spacing: tab.s(6)
        Text { text: "MEDIA"; font.family: tab.fontFamily; font.pixelSize: tab.s(10); font.bold: true; color: tab.subfg; font.letterSpacing: 1 }
        Flow {
            id: grid
            Layout.fillWidth: true
            spacing: tab.s(8)
            readonly property real tileW: Math.floor((width - spacing) / 2)
            Repeater {
                model: tab.files
                delegate: Rectangle {
                    id: tile
                    required property string modelData
                    readonly property bool isCurrent: tab.current === modelData
                    width: grid.tileW
                    height: Math.round(grid.tileW / 2)
                    radius: tab.cornerRadius
                    color: tab.surface
                    clip: true
                    border.width: isCurrent ? 2 : 0
                    border.color: tab.accent
                    Image {
                        anchors.fill: parent
                        source: tab.thumbDir !== "" ? tab.thumbUrl(tile.modelData) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: tab.isGif(tile.modelData) ? 0.35 : (area.containsMouse || tile.isCurrent ? 1 : 0.8)
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: tab.s(18)
                        color: Qt.rgba(0, 0, 0, 0.55)
                        Text {
                            anchors { fill: parent; leftMargin: tab.s(6); rightMargin: tab.s(6) }
                            verticalAlignment: Text.AlignVCenter
                            text: tab.shortName(tile.modelData) + (tab.isGif(tile.modelData) ? "  (GIF: can't play)" : "")
                            elide: Text.ElideRight
                            font.family: tab.fontFamily; font.pixelSize: tab.s(9); color: "#ffffff"
                        }
                    }
                    // hover "x" to delete
                    Rectangle {
                        visible: (area.containsMouse || xArea.containsMouse) && tab.confirmName !== tile.modelData
                        anchors { top: parent.top; right: parent.right; margins: tab.s(5) }
                        width: tab.s(20); height: width; radius: width / 2
                        color: xArea.containsMouse ? tab.errorColor : Qt.rgba(0, 0, 0, 0.6)
                        z: 2
                        Text { anchors.centerIn: parent; text: "✕"; color: "#ffffff"; font.pixelSize: tab.s(10); font.family: tab.fontFamily }
                        MouseArea { id: xArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tab.requestDelete(tile.modelData) }
                    }
                    // confirm overlay
                    Rectangle {
                        visible: tab.confirmName === tile.modelData
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.78)
                        z: 3
                        MouseArea { anchors.fill: parent; hoverEnabled: true }
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: tab.s(6)
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Delete from cooler?"; color: "#ffffff"; font.family: tab.fontFamily; font.pixelSize: tab.s(11); font.bold: true }
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter; spacing: tab.s(6)
                                Chip {
                                    label: "Delete"; active: true
                                    onClicked: tab.confirmDelete()
                                    surface: tab.surface; hover: tab.surfaceHi; accent: tab.errorColor; accentText: "#1e1e2e"; fg: tab.fg
                                    fontFamily: tab.fontFamily; ui: tab.ui; cornerRadius: tab.cornerRadius
                                }
                                Chip {
                                    label: "Cancel"
                                    onClicked: tab.confirmName = ""
                                    surface: tab.surface; hover: tab.surfaceHi; accent: tab.accent; accentText: tab.accentText; fg: tab.fg
                                    fontFamily: tab.fontFamily; ui: tab.ui; cornerRadius: tab.cornerRadius
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: tab.isGif(tile.modelData) ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                        onClicked: tab.play(tile.modelData)
                    }
                }
            }
        }
        Text {
            visible: tab.loaded && tab.files.length === 0
            text: "No media yet. Drop files into the folder below."
            font.family: tab.fontFamily; font.pixelSize: tab.s(11); color: tab.subfg
        }
    }

    // Drop folder
    RowLayout {
        Layout.fillWidth: true; spacing: tab.s(8)
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Text {
                text: tab.slowSync ? "Syncing new media…" : "Drop folder"
                font.family: tab.fontFamily; font.pixelSize: tab.s(12); font.bold: true
                color: tab.slowSync ? tab.accent : tab.fg
            }
            Text {
                Layout.fillWidth: true
                text: tab.dropDir !== "" ? tab.tilde(tab.dropDir) : "Add videos, GIFs or images"
                elide: Text.ElideMiddle
                font.family: tab.fontFamily; font.pixelSize: tab.s(10); color: tab.subfg
            }
        }
        Chip {
            label: "Open"
            enabled: tab.dropDir !== ""
            onClicked: Quickshell.execDetached(["xdg-open", tab.dropDir])
            surface: tab.surface; hover: tab.surfaceHi; accent: tab.accent; accentText: tab.accentText; fg: tab.fg
            fontFamily: tab.fontFamily; ui: tab.ui; cornerRadius: tab.cornerRadius
        }
    }

    // Brightness
    ColumnLayout {
        Layout.fillWidth: true; spacing: tab.s(6)
        RowLayout {
            Layout.fillWidth: true
            Text { text: "BRIGHTNESS"; font.family: tab.fontFamily; font.pixelSize: tab.s(10); font.bold: true; color: tab.subfg; font.letterSpacing: 1; Layout.fillWidth: true }
            Text { text: Math.round(tab.brightness) + "%"; font.family: tab.fontFamily; font.pixelSize: tab.s(11); color: tab.subfg }
        }
        BarSlider {
            id: brightBar
            Layout.fillWidth: true; ui: tab.ui
            value: tab.brightness; track: tab.surfaceHi; fill: tab.accent; knob: tab.fg
            onMoved: v => tab.brightness = v
            onCommitted: v => tab.setBrightness(v)
        }
    }

    // Keepalive
    RowLayout {
        Layout.fillWidth: true; spacing: tab.s(8)
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Text { text: "Keep display on"; font.family: tab.fontFamily; font.pixelSize: tab.s(12); font.bold: true; color: tab.fg }
            Text {
                text: tab.daemon === "active" ? "Keepalive running" : "Screen reverts to default after ~60s"
                font.family: tab.fontFamily; font.pixelSize: tab.s(10); color: tab.subfg
            }
        }
        Chip {
            label: tab.daemon === "active" ? "On" : "Off"
            active: tab.daemon === "active"
            onClicked: tab.toggleDaemon()
            surface: tab.surface; hover: tab.surfaceHi; accent: tab.accent; accentText: tab.accentText; fg: tab.fg
            fontFamily: tab.fontFamily; ui: tab.ui; cornerRadius: tab.cornerRadius
        }
    }

    Text {
        Layout.fillWidth: true
        text: tab.status
        visible: tab.status !== ""
        wrapMode: Text.Wrap
        font.family: tab.fontFamily; font.pixelSize: tab.s(10)
        color: tab.busy ? tab.subfg : tab.errorColor
        opacity: 0.9
    }
}
