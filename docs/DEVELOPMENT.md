# Development notes

Goal: Quickshell bar button -> popout to control PC RGB (OpenRGB) and the TRYX Panorama SE display (reed-tpse).
Shell-agnostic: qml/ is the UI, backend/ the scripts, adapters/ per-shell glue.

Hardware this was built on: ASRock X870E Taichi, ENE DRAM x2, Gigabyte RX 9060 XT (all via OpenRGB); TRYX panel on /dev/ttyACM0
(root:uucp 660) plus adb. Lian Li SL V3 wireless fans are out of scope (no OpenRGB support).

## State
- reed-tpse audited + patched: patches/0001 (adb hardening, service path) + 0002 (`--mode full|split`). Apply in order on upstream 69c7397.
- Lighting tab DONE (rgb-ctl; works via openrgb --server if running, else standalone).
- Display tab DONE, full-screen only: thumbnail grid, tap to play, brightness, keepalive toggle (qml/DisplayTab.qml + backend/tryx-ctl).
- Serpantinum adapter (adapters/serpantinum/install.sh --enable): bar button + glass popout. Needs `serpantinum reload` after
  QML/qmldir changes (hot reload does not pick up registry/qmldir edits). The shell dir has explicit qmldir files: new QML types need a qmldir entry.

## Hard-won facts
- DROP FOLDER: ~/Videos/tryx-display (override: TRYX_MEDIA_DIR or ~/.config/rgb-display-widget/media-dir). backend/tryx-sync converts non-panel-safe
  files (GIFs, images, odd codecs) to 2:1 H.264 MP4, adb-pushes them, keeps a manifest in ~/.cache/rgb-display-widget/sync.json, and only ever deletes
  files it uploaded itself. The widget syncs on open and every 4s while the Display tab is visible. Tested end to end (add, convert, no-op, remove).
- Hosts launch scripts with a PATH lacking ~/.local/bin. A bare `reed-tpse` then resolved to the directory ~/reed-tpse ("Is a directory").
  tryx-ctl/rgb-ctl now export PATH themselves. Always test backends with `env -i HOME=$HOME PATH=/usr/bin ...` from $HOME.
- Panel runs Android; vendor apps com.baiyi.homeui.tkcfanhomeui / com.baiyi.service.serialservice.serialdataservice. Its UI strings: screenMode
  "Full Screen" | "Screen Splitting"; ratio "2:1" | "1:1". Media lives in /sdcard/pcMedia/ on the device (uploaded earlier by the Windows app).
- SPLIT MODE DOES NOT WORK yet: "Screen Splitting" with 2:1 or 1:1 and two media gives a BLANK screen (device replies 200 OK). 1:1 + Full Screen
  gives a square video on the left half. The real split message format is unknown; next step would be decompiling com.baiyi...entity.ScreenConfig
  from HomeUI.apk (pull with `adb pull $(adb shell pm path PKG)`). Do NOT blind-try values on the user's screen again.
- reed-tpse rewrites .gif -> .mp4 in the saved/sent media name but only `upload` converts. Displaying a raw .gif = blank screen. tryx-ctl refuses gifs.
- While the keepalive daemon is running, reed-tpse auto-detect fails ("No device found"); always pass -p /dev/ttyACMx (tryx-ctl does).
- Without keepalive the panel reverts to its default screen after ~60s.
- zsh: never name a variable `path` (tied to PATH).

## TODO (ideas, none required)
1. Split screen layout (needs the ScreenConfig decompile above).
2. Upload/delete media from the UI (needs a file picker; tryx-ctl upload/delete already exist).
3. Lighting presets (save/load per-device mode+colour; OpenRGB cannot read colours back, so the panel must remember what it applied).
4. Rename the bulb button/icon to something generic; git commit + publish this repo.
