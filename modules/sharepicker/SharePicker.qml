pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components.containers
import qs.services

Scope {
    id: root

    property bool active: false
    property bool shown: false
    property string requestId: ""
    property string windowListRaw: ""
    property bool allowRestoreToken: true
    property ShellScreen promptScreen

    readonly property ShellScreen focusedScreen: Screens.screens.find(s => Hypr.monitorFor(s) === Hypr.focusedMonitor) ?? Screens.screens[0]

    function openPicker(reqId: string, windowsData: string, allowToken: bool): void {
        closeTimer.stop();
        root.requestId = reqId;
        root.windowListRaw = windowsData;
        root.allowRestoreToken = allowToken;
        root.promptScreen = root.focusedScreen;
        root.active = true;
        root.shown = true;
    }

    function finishSelection(resultLine: string): void {
        if (!root.active)
            return;

        const outPath = `/tmp/nyx-share-res-${root.requestId}`;
        if (resultLine !== "") {
            Quickshell.execDetached(["sh", "-c", `printf '%s\\n' "$1" > "$2"`, "_", resultLine, outPath]);
        } else {
            Quickshell.execDetached(["sh", "-c", `: > "$1"`, "_", outPath]);
        }

        root.active = false;
        closeTimer.restart();
    }

    Timer {
        id: closeTimer
        interval: 260
        onTriggered: {
            root.shown = false;
            root.requestId = "";
            root.windowListRaw = "";
        }
    }

    IpcHandler {
        target: "sharepicker"

        function open(reqId: string, windowsData: string, allowToken: string): void {
            root.openPicker(reqId, windowsData, allowToken === "1" || allowToken === "true");
        }
    }

    StyledWindow {
        id: window

        name: "sharepicker"
        screen: root.promptScreen ?? root.focusedScreen
        visible: root.shown
        implicitWidth: screen.width
        implicitHeight: screen.height

        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Content {
            anchors.fill: parent
            active: root.active
            windowListRaw: root.windowListRaw
            allowRestoreToken: root.allowRestoreToken
            onAccepted: result => root.finishSelection(result)
            onCancelled: root.finishSelection("")
        }
    }
}
