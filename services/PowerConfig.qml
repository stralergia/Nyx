pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.utils

Singleton {
    id: root

    readonly property bool pauseGraph: enabled && PowerProfiles.profile === PowerProfile.PowerSaver && pauseGraphInPowerSaver
    readonly property bool pauseVisualisers: enabled && PowerProfiles.profile === PowerProfile.PowerSaver && pauseVisualisersInPowerSaver

    property bool loaded: false

    Timer {
        id: saveTimer

        interval: 250
        onTriggered: {
            if (root.loaded)
                stateFile.writeAdapter();
        }
    }

    FileView {
        id: stateFile

        path: `${Paths.state}/power.json`
        watchChanges: false
        onLoaded: root.loaded = true
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                writeAdapter();
            }
        }

        JsonAdapter {
            id: store

            property bool enabled: true
            property bool pauseGraphInPowerSaver: true
            property bool pauseVisualisersInPowerSaver: true

            property bool shutdownEnabled: false
            property int shutdownLevel: 5
            property int shutdownDelay: 60

            property string onChargingProfile: "balanced"
            property string onChargingRefreshRate: "165"
            property string onUnpluggedProfile: "power-saver"
            property string onUnpluggedRefreshRate: "60"
            property bool onUnpluggedThresholds: false

            property var thresholds: []

            property string psRefreshRate: "60"
            property string psDisableAnimations: "disable"
            property string psDisableBlur: "disable"
            property string psDisableRounding: ""
            property string psDisableShadows: "disable"

            property string balRefreshRate: "165"
            property string balDisableAnimations: "enable"
            property string balDisableBlur: "enable"
            property string balDisableRounding: ""
            property string balDisableShadows: "enable"

            property string perfRefreshRate: "165"
            property string perfDisableAnimations: "enable"
            property string perfDisableBlur: "enable"
            property string perfDisableRounding: ""
            property string perfDisableShadows: "enable"

            onEnabledChanged: saveTimer.restart()
            onPauseGraphInPowerSaverChanged: saveTimer.restart()
            onPauseVisualisersInPowerSaverChanged: saveTimer.restart()
            onShutdownEnabledChanged: saveTimer.restart()
            onShutdownLevelChanged: saveTimer.restart()
            onShutdownDelayChanged: saveTimer.restart()
            onOnChargingProfileChanged: saveTimer.restart()
            onOnChargingRefreshRateChanged: saveTimer.restart()
            onOnUnpluggedProfileChanged: saveTimer.restart()
            onOnUnpluggedRefreshRateChanged: saveTimer.restart()
            onOnUnpluggedThresholdsChanged: saveTimer.restart()
            onThresholdsChanged: saveTimer.restart()

            onPsRefreshRateChanged: saveTimer.restart()
            onPsDisableAnimationsChanged: saveTimer.restart()
            onPsDisableBlurChanged: saveTimer.restart()
            onPsDisableRoundingChanged: saveTimer.restart()
            onPsDisableShadowsChanged: saveTimer.restart()

            onBalRefreshRateChanged: saveTimer.restart()
            onBalDisableAnimationsChanged: saveTimer.restart()
            onBalDisableBlurChanged: saveTimer.restart()
            onBalDisableRoundingChanged: saveTimer.restart()
            onBalDisableShadowsChanged: saveTimer.restart()

            onPerfRefreshRateChanged: saveTimer.restart()
            onPerfDisableAnimationsChanged: saveTimer.restart()
            onPerfDisableBlurChanged: saveTimer.restart()
            onPerfDisableRoundingChanged: saveTimer.restart()
            onPerfDisableShadowsChanged: saveTimer.restart()
        }
    }

    property alias enabled: store.enabled
    property alias pauseGraphInPowerSaver: store.pauseGraphInPowerSaver
    property alias pauseVisualisersInPowerSaver: store.pauseVisualisersInPowerSaver
    property alias thresholds: store.thresholds

    readonly property QtObject shellShutdown: QtObject {
        property alias enabled: store.shutdownEnabled
        property alias level: store.shutdownLevel
        property alias delay: store.shutdownDelay
    }

    readonly property QtObject onCharging: QtObject {
        property alias setPowerProfile: store.onChargingProfile
        property alias setRefreshRate: store.onChargingRefreshRate
    }

    readonly property QtObject onUnplugged: QtObject {
        property alias setPowerProfile: store.onUnpluggedProfile
        property alias setRefreshRate: store.onUnpluggedRefreshRate
        property alias evaluateThresholds: store.onUnpluggedThresholds
    }

    readonly property QtObject profileBehaviors: QtObject {
        readonly property QtObject powerSaver: QtObject {
            property alias setRefreshRate: store.psRefreshRate
            property alias disableAnimations: store.psDisableAnimations
            property alias disableBlur: store.psDisableBlur
            property alias disableRounding: store.psDisableRounding
            property alias disableShadows: store.psDisableShadows
        }
        readonly property QtObject balanced: QtObject {
            property alias setRefreshRate: store.balRefreshRate
            property alias disableAnimations: store.balDisableAnimations
            property alias disableBlur: store.balDisableBlur
            property alias disableRounding: store.balDisableRounding
            property alias disableShadows: store.balDisableShadows
        }
        readonly property QtObject performance: QtObject {
            property alias setRefreshRate: store.perfRefreshRate
            property alias disableAnimations: store.perfDisableAnimations
            property alias disableBlur: store.perfDisableBlur
            property alias disableRounding: store.perfDisableRounding
            property alias disableShadows: store.perfDisableShadows
        }
    }
}
