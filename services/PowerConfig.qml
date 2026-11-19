pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property bool pauseGraph: enabled && PowerProfiles.profile === PowerProfile.PowerSaver && pauseGraphInPowerSaver
    readonly property bool pauseVisualisers: enabled && PowerProfiles.profile === PowerProfile.PowerSaver && pauseVisualisersInPowerSaver

    PersistentProperties {
        id: store
        reloadableId: "nyxPowerConfig"

        property bool enabled: false
        property bool pauseGraphInPowerSaver: false
        property bool pauseVisualisersInPowerSaver: false

        property var shellShutdown: ({
            enabled: false,
            level: 5,
            delay: 60
        })

        property var onCharging: ({
            setPowerProfile: "restore"
        })

        property var onUnplugged: ({
            setPowerProfile: "",
            evaluateThresholds: false
        })

        property var thresholds: []

        property var profileBehaviors: ({
            powerSaver: {
                setRefreshRate: "",
                disableAnimations: "",
                disableBlur: "",
                disableRounding: "",
                disableShadows: ""
            },
            balanced: {
                setRefreshRate: "",
                disableAnimations: "",
                disableBlur: "",
                disableRounding: "",
                disableShadows: ""
            },
            performance: {
                setRefreshRate: "",
                disableAnimations: "",
                disableBlur: "",
                disableRounding: "",
                disableShadows: ""
            }
        })
    }

    property alias enabled: store.enabled
    property alias pauseGraphInPowerSaver: store.pauseGraphInPowerSaver
    property alias pauseVisualisersInPowerSaver: store.pauseVisualisersInPowerSaver
    property alias shellShutdown: store.shellShutdown
    property alias onCharging: store.onCharging
    property alias onUnplugged: store.onUnplugged
    property alias thresholds: store.thresholds
    property alias profileBehaviors: store.profileBehaviors
}
