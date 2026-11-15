pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.components.containers
import qs.services

Scope {
    id: root

    property ShellScreen promptScreen
    readonly property ShellScreen focusedScreen: Screens.screens.find(s => Hypr.monitorFor(s) === Hypr.focusedMonitor) ?? Screens.screens[0]
    readonly property var agent: agentLoader.item
    readonly property bool active: root.agent?.isActive ?? false
    property bool shown

    onActiveChanged: {
        if (root.active) {
            closeTimer.stop();
            root.shown = true;
        } else if (root.shown) {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: root.shown = false
    }

    Loader {
        id: agentLoader
        active: true
        sourceComponent: PolkitAgent {
            path: "/org/nyx/PolkitAgent"
            onAuthenticationRequestStarted: root.promptScreen = root.focusedScreen
        }
    }

    StyledWindow {
        id: window

        name: "polkit"
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
            flow: root.agent?.flow ?? null
        }
    }

    Timer {
        id: retryTimer

        readonly property int maxAttempts: 6
        property int attempts

        interval: 10000
        repeat: true
        running: root.agent !== null && !root.agent.isRegistered && !root.active

        onTriggered: {
            if (++attempts > maxAttempts) {
                stop();
                console.warn("Polkit agent could not register - another authentication agent holds this session");
                return;
            }
            agentLoader.active = false;
            agentLoader.active = true;
        }
    }

    Connections {
        function onIsRegisteredChanged(): void {
            if (root.agent?.isRegistered)
                retryTimer.attempts = 0;
        }
        target: root.agent
    }
}
