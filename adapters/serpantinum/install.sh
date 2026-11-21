#!/usr/bin/env bash
# Installs the RGB bar module + popout into a Serpantinum Quickshell tree.
#   ./install.sh [--enable] [SHELL_DIR]
# --enable also adds "rgb" to the bar layout in ~/.config/serpantinum/settings.json.
# Idempotent. Backs up every file it modifies to <SHELL_DIR>/.rgbpanel-backup/<timestamp>/.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
enable=0; [[ "${1:-}" == "--enable" ]] && { enable=1; shift; }
sh="${1:-$HOME/.local/share/serpantinum/src/quickshell}"
[[ -f "$sh/qmldir" && -d "$sh/bar/faces" ]] || { echo "Not a Serpantinum shell dir: $sh" >&2; exit 1; }

bak="$sh/.rgbpanel-backup/$(date +%Y%m%d-%H%M%S)"
backup() { [[ -e "$1" ]] || return 0; mkdir -p "$bak/$(dirname "${1#$sh/}")"; cp -a "$1" "$bak/${1#$sh/}"; }

# 1. Files
mkdir -p "$sh/bar/faces/rgb"
for f in popouts/RgbPopout.qml:RgbPopout.qml bar/faces/rgb/RgbFace.qml:RgbFace.qml singletons/widgetcontrols/RgbController.qml:RgbController.qml; do
  dst="$sh/${f%%:*}"; backup "$dst"; cp "$here/${f##*:}" "$dst"
done
# 2. Portable panel, linked so edits in the repo apply immediately
if [[ -L "$sh/rgbpanel" || ! -e "$sh/rgbpanel" ]]; then ln -sfn "$repo/qml" "$sh/rgbpanel"; else echo "$sh/rgbpanel exists and is not a symlink" >&2; exit 1; fi

# 3. Registrations
python3 - "$sh" "$bak" <<'PY'
import sys, os, shutil
sh, bak = sys.argv[1], sys.argv[2]
def edit(rel, fn):
    p = os.path.join(sh, rel); s = open(p).read(); n = fn(s)
    if n != s:
        d = os.path.join(bak, os.path.dirname(rel)); os.makedirs(d, exist_ok=True); shutil.copy2(p, os.path.join(bak, rel))
        open(p, "w").write(n); print("patched", rel)
def qmldir(s):
    for line, after in (("RgbPopout 1.0 popouts/RgbPopout.qml", "SideMusicPopout 1.0 popouts/SideMusicPopout.qml"),
                        ("singleton RgbController 1.0 singletons/widgetcontrols/RgbController.qml", "singleton SideMusicController 1.0 singletons/widgetcontrols/SideMusicController.qml")):
        if line not in s: s = s.replace(after, after + "\n" + line, 1)
    return s
def manager(s):
    return s if "RgbPopout" in s else s.replace("    SideMusicPopout {}", "    SideMusicPopout {}\n    RgbPopout {}", 1)
ENTRY = '''        "rgb": {
            name: "RGB Lighting",
            icon: "\\udb80\\udf36",
            defaultVariant: "default",
            face: "faces/rgb/RgbFace.qml"
        },
'''
def registry(s):
    return s if '"rgb":' in s else s.replace('        "tray": {', ENTRY + '        "tray": {', 1)
edit("qmldir", qmldir); edit("popouts/PopoutManager.qml", manager); edit("bar/BarModuleRegistry.qml", registry)
PY

# 4. Optional: put it on the bar
if (( enable )); then
python3 - <<'PY'
import json, os, shutil, time
p = os.path.expanduser("~/.config/serpantinum/settings.json")
s = json.load(open(p)); m = s["bar"]["modules"]
flat = lambda a: [x for i in a for x in (i if isinstance(i, list) else [i])]
if "rgb" in flat(m.get("left", [])) + flat(m.get("center", [])) + flat(m.get("right", [])):
    print("rgb already on bar")
else:
    shutil.copy2(p, p + ".rgbpanel-bak-" + time.strftime("%Y%m%d-%H%M%S"))
    r = m["right"]; r.insert(r.index("tray") if "tray" in r else 0, "rgb")
    json.dump(s, open(p, "w"), indent=2); print("added rgb to bar (right, before tray)")
PY
fi
echo "Done. Backups in $bak"
