pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Wallpaper bridge — keeps a warm in-memory snapshot of ~/Ricelin/wallpapers so
 * the wallpaper strip opens instantly instead of shelling out on demand. A
 * refresh first runs the thumbnail script (generating missing 512px previews
 * and pruning ones whose source is gone), then re-lists the directory
 * newest-first and finally re-reads the state file wallpaper.sh maintains, so
 * `current` always names the wallpaper on screen. Thumbnails land before the
 * list so strip delegates never bind to a not-yet-existing file; a refresh
 * arriving while the pipeline runs sets `pending` and replays once the state
 * lands. Applying routes through wallpaper.sh so the picker shares the exact
 * transition, palette and state path with the random keybind.
 *
 * Entries are plain objects: { path, name, mtime, thumb } where path is the
 * absolute source file, mtime its modification time in epoch seconds and
 * thumb the absolute path of the cached preview png.
 */
Singleton {
    id: root

    property var entries: []
    readonly property int count: entries.length
    property string current: ""
    property bool pending: false

    readonly property string wpDir: Quickshell.env("HOME") + "/Ricelin/wallpapers"
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ricelin-wp-thumbs/"
    readonly property string thumbScript: Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-thumbs.sh"
    readonly property string setScript: Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh"
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin-wallpaper"

    function refresh() {
        if (thumbProc.running || listProc.running || stateProc.running) {
            pending = true;
            return;
        }
        thumbProc.running = true;
    }

    /**
     * wallpaper.sh blocks through the whole transition (awww wave, wallust,
     * reload), easily 1-2s; a pick landing in that window used to be silently
     * swallowed. The newest request is queued instead and replayed once the
     * running transition exits, so rapid iteration always converges on the
     * last pick.
     */
    property string queuedApply: ""

    function apply(path) {
        if (applyProc.running) {
            queuedApply = path;
            return;
        }
        applyProc.command = ["bash", root.setScript, "set", path];
        applyProc.running = true;
    }

    function trash(path) {
        trashProc.command = ["gio", "trash", path];
        trashProc.running = true;
        var kept = [];
        for (var i = 0; i < entries.length; i++)
            if (entries[i].path !== path)
                kept.push(entries[i]);
        entries = kept;
    }

    Process {
        id: trashProc
        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.refresh();
        }
    }

    Process {
        id: thumbProc
        command: ["sh", root.thumbScript]
        onExited: listProc.running = true
    }

    Process {
        id: listProc
        command: ["sh", "-c", "find \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.png' \\) -printf '%T@\\t%p\\n' | sort -rn", "_", root.wpDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; i++) {
                    var tab = lines[i].indexOf("\t");
                    if (tab < 1)
                        continue;
                    var path = lines[i].substring(tab + 1);
                    var name = path.substring(path.lastIndexOf("/") + 1);
                    out.push({
                        path: path,
                        name: name,
                        mtime: parseFloat(lines[i].substring(0, tab)),
                        thumb: root.thumbDir + name + ".png"
                    });
                }
                root.entries = out;
                stateProc.running = true;
            }
        }
    }

    Process {
        id: stateProc
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "_", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                root.current = this.text.trim();
                if (root.pending) {
                    root.pending = false;
                    Qt.callLater(root.refresh);
                }
            }
        }
    }

    Process {
        id: applyProc
        onExited: {
            if (root.queuedApply.length) {
                var next = root.queuedApply;
                root.queuedApply = "";
                applyProc.command = ["bash", root.setScript, "set", next];
                applyProc.running = true;
                return;
            }
            stateProc.running = true;
        }
    }

    Component.onCompleted: refresh()
}
