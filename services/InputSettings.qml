pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property string sensitivityKey: "input:sensitivity"
    readonly property string accelProfileKey: "input:accel_profile"
    readonly property string forceNoAccelKey: "input:force_no_accel"
    readonly property string scrollFactorKey: "input:scroll_factor"
    readonly property string touchpadScrollFactorKey: "input:touchpad:scroll_factor"
    readonly property string naturalScrollKey: "input:touchpad:natural_scroll"

    readonly property string configPath: `${Paths.config}/hypr-user.lua`

    property var overrides: ({})
    property string savedText: ""
    property bool loaded: false
    property var fileOverrides: ({})

    // Cursor state
    property var cursorThemes: ["default"]
    property string cursorTheme: "default"
    property int cursorSize: 24

    readonly property real sensitivity: root.current(root.sensitivityKey, 0)
    readonly property string accelProfile: root.current(root.accelProfileKey, "")
    readonly property real scrollFactor: root.current(root.scrollFactorKey, 1)
    readonly property real touchpadScrollFactor: root.current(root.touchpadScrollFactorKey, 1)
    readonly property bool naturalScroll: root.current(root.naturalScrollKey, false)

    function current(key: string, fallback: var): var {
        return root.overrides[key] ?? root.fileOverrides[key] ?? fallback;
    }

    function set(key: string, value: var): void {
        const next = Object.assign({}, root.overrides);
        next[key] = value;
        root.overrides = next;
        commitTimer.restart();
    }

    function setAccel(enabled: bool): void {
        root.set(root.accelProfileKey, enabled ? "adaptive" : "flat");
        root.set(root.forceNoAccelKey, !enabled);
    }

    function setCursor(theme: string, size: int): void {
        root.cursorTheme = theme;
        root.cursorSize = size;
        props.cursorTheme = theme;
        props.cursorSize = size;
        cursorProc.command = [
            "sh", "-c",
            `hyprctl setcursor "${theme}" ${size}; gsettings set org.gnome.desktop.interface cursor-theme "${theme}" 2>/dev/null || true; gsettings set org.gnome.desktop.interface cursor-size ${size} 2>/dev/null || true`
        ];
        cursorProc.running = true;
        commitTimer.restart();
    }

    function apply(): void {
        if (Object.keys(root.overrides).length > 0)
            Hypr.extras.applyOptions(root.overrides);
    }

    function commit(): void {
        props.overrides = root.merged();
        root.apply();
        root.write();
    }

    readonly property string blockStart: "-- >>> caelestia input settings"
    readonly property string blockEnd: "-- <<< caelestia input settings"

    function nest(overrides: var): var {
        const nested = {};
        for (const key in overrides) {
            const parts = key.split(":");
            let node = nested;
            for (let i = 0; i < parts.length - 1; i++) {
                if (!node[parts[i]])
                    node[parts[i]] = {};
                node = node[parts[i]];
            }
            node[parts[parts.length - 1]] = overrides[key];
        }
        return nested;
    }

    function luaValue(value: var): string {
        if (typeof value === "string")
            return `"${value.replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
        return String(value);
    }

    function luaTable(table: var, indent: string): string {
        return Object.keys(table).sort().map(key => {
            const value = table[key];
            if (value !== null && typeof value === "object")
                return `${indent}${key} = {\n${root.luaTable(value, indent + "    ")}\n${indent}},`;
            return `${indent}${key} = ${root.luaValue(value)},`;
        }).join("\n");
    }

    function parseLuaValue(raw: string): var {
        const value = raw.trim();
        if (value === "true")
            return true;
        if (value === "false")
            return false;
        if (/^".*"$/.test(value))
            return value.slice(1, -1).replace(/\\"/g, "\"").replace(/\\\\/g, "\\");
        const num = Number(value);
        return value !== "" && Number.isFinite(num) ? num : value;
    }

    function parseBlock(text: string): var {
        const start = text.indexOf(root.blockStart);
        if (start === -1)
            return ({});
        const end = text.indexOf(root.blockEnd, start);
        if (end === -1)
            return ({});

        const blockText = text.slice(start + root.blockStart.length, end);

        const themeMatch = /hl\.env\("(?:HYPRCURSOR|XCURSOR)_THEME",\s*"([^"]+)"\)/.exec(blockText);
        if (themeMatch)
            root.cursorTheme = themeMatch[1];

        const sizeMatch = /hl\.env\("(?:HYPRCURSOR|XCURSOR)_SIZE",\s*"(\d+)"\)/.exec(blockText);
        if (sizeMatch)
            root.cursorSize = parseInt(sizeMatch[1], 10);

        const parsed = {};
        const path = [];
        for (const raw of blockText.split("\n")) {
            const line = raw.trim();
            if (line === "" || line.startsWith("--") || line.startsWith("hl.config") || line.startsWith("hl.env") || line === "})")
                continue;
            if (line === "}," || line === "}") {
                path.pop();
                continue;
            }

            const open = /^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{$/.exec(line);
            if (open) {
                path.push(open[1]);
                continue;
            }

            const leaf = /^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?),?$/.exec(line);
            if (leaf)
                parsed[path.concat(leaf[1]).join(":")] = root.parseLuaValue(leaf[2]);
        }
        return parsed;
    }

    function merged(): var {
        return Object.assign({}, root.fileOverrides, root.overrides);
    }

    function block(): string {
        let out = `${root.blockStart}\n`;
        const m = root.merged();
        if (Object.keys(m).length > 0) {
            out += `hl.config({\n${root.luaTable(root.nest(m), "    ")}\n})\n`;
        }
        out += `hl.env("XCURSOR_THEME", ${root.luaValue(root.cursorTheme)})\n`;
        out += `hl.env("XCURSOR_SIZE", "${root.cursorSize}")\n`;
        out += `hl.env("HYPRCURSOR_THEME", ${root.luaValue(root.cursorTheme)})\n`;
        out += `hl.env("HYPRCURSOR_SIZE", "${root.cursorSize}")\n`;
        out += `${root.blockEnd}\n`;
        return out;
    }

    function replaced(text: string): string {
        const body = text.replace(/-- >>> caelestia input settings[\s\S]*?-- <<< caelestia input settings\n?/g, "").replace(/\s+$/, "");
        return `${body}${body ? "\n\n" : ""}${root.block()}`;
    }

    function write(): void {
        if (!root.loaded)
            return;

        const next = root.replaced(root.savedText);
        if (next !== root.savedText)
            storage.setText(next);
    }

    Component.onCompleted: {
        if (!root.loaded) {
            root.fileOverrides = Object.assign({}, props.overrides);
            if (props.cursorTheme)
                root.cursorTheme = props.cursorTheme;
            if (props.cursorSize > 0)
                root.cursorSize = props.cursorSize;
        }
        scanThemesProc.running = true;
    }

    Process {
        id: scanThemesProc
        command: [
            "sh", "-c",
            "find /usr/share/icons ~/.local/share/icons ~/.icons -mindepth 2 -maxdepth 2 -type d -name cursors 2>/dev/null | xargs -r -n1 dirname | xargs -r -n1 basename | sort -u"
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                const rawList = data.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);
                // Kalabalık yapan gereksiz varyantları filtrele (sadece ana/temiz temalar kalsın)
                const filtered = rawList.filter(s => {
                    const lower = s.toLowerCase();
                    if (lower.includes("-right")) return false;
                    if (lower.includes("-original")) return false;
                    if (lower.includes("-ice")) return false;
                    if (lower.includes("-amber")) return false;
                    return true;
                });
                root.cursorThemes = filtered.length > 0 ? filtered : rawList;
            }
        }
    }

    Process {
        id: cursorProc
    }

    Timer {
        id: commitTimer

        interval: 150
        onTriggered: root.commit()
    }

    Connections {
        function onConfigReloaded(): void {
            root.apply();
        }

        target: Hypr
    }

    FileView {
        id: storage

        path: root.configPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.savedText = text();
            root.fileOverrides = root.parseBlock(root.savedText);
            root.loaded = true;
            root.write();
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.savedText = "";
                root.fileOverrides = ({});
                root.loaded = true;
                root.write();
            }
        }
    }

    PersistentProperties {
        id: props

        property var overrides: ({})
        property string cursorTheme: "default"
        property int cursorSize: 24

        reloadableId: "inputSettings"
    }
}
