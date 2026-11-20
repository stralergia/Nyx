import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.services

Scope {
    id: root

    readonly property list<var> warnLevels: [...GlobalConfig.general.battery.warnLevels.values].sort((a, b) => a.level - b.level)
    readonly property list<var> powerThresholds: [...(PowerConfig.thresholds ?? [])].sort((a, b) => b.level - a.level)
    readonly property bool powerManagementEnabled: PowerConfig.enabled && PowerConfig.loaded

    property real lastPercentage: 100
    property var originalSettings: ({
        refreshRates: {}
    })
    property int currentThresholdIndex: -1
    property bool settingsModified: false
    property int originalProfile: -1
    property int expectedProfile: -1
    property bool initialised: false

    readonly property list<string> effectKeys: ["disableAnimations", "disableBlur", "disableRounding", "disableShadows"]

    PersistentProperties {
        id: desktopDefault

        property bool applied: false

        reloadableId: "batteryMonitorDesktopDefault"
    }

    function applyDesktopDefault(): void {
        if (desktopDefault.applied || UPower.displayDevice.isLaptopBattery)
            return;

        desktopDefault.applied = true;
        if (PowerProfiles.hasPerformanceProfile)
            PowerProfiles.profile = PowerProfile.Performance;
    }

    property int shutdownRemaining: 0
    property bool shutdownFired: false
    readonly property var shutdownConfig: PowerConfig.shellShutdown

    function shutdownText(secs: int): string {
        return secs >= 60 && secs % 60 === 0 ? Tr.tr("%1 min").arg(secs / 60) : Tr.tr("%1 s").arg(secs);
    }

    function warnShutdown(secs: int): void {
        Toaster.toast(Tr.tr("Critical battery"), Tr.tr("Shell shuts down in %1. Plug in to cancel.").arg(root.shutdownText(secs)), "battery_android_alert", Toast.Error, Math.max(5000, secs * 1000));
    }

    function startShellShutdown(): void {
        root.shutdownRemaining = Math.max(1, root.shutdownConfig.delay);
        root.warnShutdown(root.shutdownRemaining);
        shutdownTimer.start();
    }

    function cancelShellShutdown(): void {
        if (!shutdownTimer.running)
            return;

        shutdownTimer.stop();
        root.shutdownRemaining = 0;
        Toaster.toast(Tr.tr("Shell shutdown cancelled"), Tr.tr("The battery is no longer critical"), "battery_charging_full", Toast.Success);
    }

    function checkShellShutdown(p: real): void {
        const critical = root.shutdownConfig.enabled && UPower.onBattery && p <= root.shutdownConfig.level;
        if (critical && !shutdownTimer.running && !root.shutdownFired)
            root.startShellShutdown();
        else if (!critical && shutdownTimer.running)
            root.cancelShellShutdown();

        if (!critical)
            root.shutdownFired = false;
    }

    function handleBatteryWarnings(): void {
        const p = UPower.displayDevice.percentage * 100;
        root.checkShellShutdown(p);

        if (!UPower.onBattery) {
            root.lastPercentage = p;
            return;
        }

        if (root.lastPercentage >= 0) {
            for (const level of root.warnLevels) {
                if (p <= level.level && root.lastPercentage > level.level) {
                    Toaster.toast(Tr.trMarked(level.title ?? Tr.tr("Battery warning")), Tr.trMarked(level.message ?? Tr.tr("Battery level is low")), level.icon ?? "battery_android_alert", level.critical ? Toast.Error : Toast.Warning);
                    break;
                }
            }
        }

        if (!hibernateTimer.running && p <= GlobalConfig.general.battery.criticalLevel) {
            Toaster.toast(Tr.tr("Hibernating in 5 seconds"), Tr.tr("Hibernating to prevent data loss"), "battery_android_alert", Toast.Error);
            hibernateTimer.start();
        }

        if (root.powerManagementEnabled)
            root.evaluateThresholds();

        root.lastPercentage = p;
    }

    function applyVisualEffects(settings): void {
        const options = {};
        if (settings.disableAnimations === "disable")
            options["animations:enabled"] = 0;
        else if (settings.disableAnimations === "enable")
            options["animations:enabled"] = 1;

        if (settings.disableBlur === "disable")
            options["decoration:blur:enabled"] = 0;
        else if (settings.disableBlur === "enable")
            options["decoration:blur:enabled"] = 1;

        if (settings.disableRounding === "disable")
            options["decoration:rounding"] = 0;
        else if (settings.disableRounding === "enable")
            options["decoration:rounding"] = 10;

        if (settings.disableShadows === "disable")
            options["decoration:shadow:enabled"] = 0;
        else if (settings.disableShadows === "enable")
            options["decoration:shadow:enabled"] = 1;

        if (Object.keys(options).length > 0)
            Hypr.extras.applyOptions(options);
    }

    function setMonitorRate(data, rate): void {
        const numericRate = Number(rate);
        if (!data || !data.name || !Number.isFinite(numericRate) || numericRate <= 0)
            return;

        let modeStr = `${data.width}x${data.height}@${numericRate.toFixed(2)}`;
        if (data.availableModes && data.availableModes.length > 0) {
            const currentResPrefix = `${data.width}x${data.height}@`;
            for (const mode of data.availableModes) {
                if (!mode.startsWith(currentResPrefix))
                    continue;
                const match = mode.match(/@(\d+(?:\.\d+)?)Hz/);
                if (match && Math.abs(parseFloat(match[1]) - numericRate) < 1.0) {
                    modeStr = mode.replace(/Hz$/, "");
                    break;
                }
            }
        }

        const posStr = `${Math.round(data.x ?? 0)}x${Math.round(data.y ?? 0)}`;
        const scaleVal = Number(data.scale ?? 1).toFixed(2).replace(/\.?0+$/, "");

        if (Hypr.usingLua ?? false) {
            Hypr.extras.message(`eval local m = hl.get_monitor("${data.name}"); if m then hl.monitor({ output = "${data.name}", mode = "${modeStr}", position = m.x .. "x" .. m.y, scale = m.scale }); end`);
        } else {
            Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${data.name},${modeStr},${posStr},${scaleVal}`]);
        }
    }

    function applyRefreshRate(rate): void {
        let targetRate;

        if (rate === "auto") {
            targetRate = root.getLowestRefreshRate();
        } else if (rate === "restore") {
            root.restoreRefreshRates();
            return;
        } else {
            targetRate = Number(rate);
        }

        if (!Number.isFinite(targetRate) || targetRate <= 0)
            return;

        for (const monitor of Hypr.monitors.values) {
            const raw = monitor.lastIpcObject;
            const data = raw ?? {
                name: monitor.name,
                width: monitor.width,
                height: monitor.height,
                x: monitor.x,
                y: monitor.y,
                scale: monitor.scale,
                availableModes: []
            };
            if (!data.name)
                continue;

            if (raw && !root.originalSettings.refreshRates[data.name] && (raw.refreshRate ?? 0) > 65)
                root.originalSettings.refreshRates[data.name] = raw.refreshRate;

            root.setMonitorRate(data, targetRate);
        }
    }

    function getHighestRefreshRate(): int {
        let highestRate = 165;

        for (const monitor of Hypr.monitors.values) {
            const data = monitor.lastIpcObject;
            if (data?.availableModes) {
                for (const mode of data.availableModes) {
                    const match = mode.match(/@(\d+(?:\.\d+)?)Hz/);
                    if (match) {
                        const rate = Math.round(parseFloat(match[1]));
                        if (rate > highestRate)
                            highestRate = rate;
                    }
                }
            }
        }

        return highestRate;
    }

    function getLowestRefreshRate(): int {
        let lowestRate = 60;

        for (const monitor of Hypr.monitors.values) {
            const data = monitor.lastIpcObject;
            if (data?.availableModes) {
                const supportedRates = [];
                for (const mode of data.availableModes) {
                    const match = mode.match(/@(\d+(?:\.\d+)?)Hz/);
                    if (match) {
                        const rate = Math.round(parseFloat(match[1]));
                        if (!supportedRates.includes(rate))
                            supportedRates.push(rate);
                    }
                }

                supportedRates.sort((a, b) => a - b);
                if (supportedRates.length > 0)
                    lowestRate = Math.min(lowestRate, supportedRates[0]);
            }
        }

        return lowestRate;
    }

    function restoreRefreshRates(): void {
        for (const monitor of Hypr.monitors.values) {
            const data = monitor.lastIpcObject;
            if (!data)
                continue;

            const originalRate = root.originalSettings.refreshRates[data.name] ?? root.getHighestRefreshRate();
            delete root.originalSettings.refreshRates[data.name];

            if (Math.abs((data.refreshRate ?? 0) - Number(originalRate)) < 0.5)
                continue;

            root.setMonitorRate(data, Number(originalRate));
        }
    }

    function profileFromName(name: string): int {
        if (name === "power-saver")
            return PowerProfile.PowerSaver;
        if (name === "balanced")
            return PowerProfile.Balanced;
        if (name === "performance")
            return PowerProfile.Performance;
        return -1;
    }

    function behaviourFor(profile: int): var {
        const behaviours = PowerConfig.profileBehaviors;
        if (profile === PowerProfile.PowerSaver)
            return behaviours.powerSaver;
        if (profile === PowerProfile.Performance)
            return behaviours.performance;
        if (profile === PowerProfile.Balanced)
            return behaviours.balanced;
        return null;
    }

    function hasValue(value: var): bool {
        return value !== undefined && value !== null && value !== "" && value !== "unchanged";
    }

    function applyActions(actions: var, restoreFallback: int): list<string> {
        let profile = -1;
        if (actions.setPowerProfile === "restore")
            profile = root.originalProfile >= 0 ? root.originalProfile : restoreFallback;
        else
            profile = root.profileFromName(actions.setPowerProfile ?? "");

        const behaviour = profile >= 0 ? root.behaviourFor(profile) : null;
        const effects = {};
        for (const key of root.effectKeys)
            effects[key] = root.hasValue(actions[key]) ? actions[key] : (behaviour && root.hasValue(behaviour[key]) ? behaviour[key] : "");

        let rate = "";
        if (root.hasValue(actions.setRefreshRate))
            rate = actions.setRefreshRate;
        else if (behaviour && root.hasValue(behaviour.setRefreshRate))
            rate = behaviour.setRefreshRate;

        if (profile >= 0 && PowerProfiles.profile !== profile) {
            root.expectedProfile = profile;
            PowerProfiles.profile = profile;
        }

        root.applyVisualEffects(effects);
        if (rate)
            root.applyRefreshRate(rate);

        return root.describe(profile, rate, effects);
    }

    function describe(profile: int, rate: string, effects: var): list<string> {
        const applied = [];
        if (profile === PowerProfile.PowerSaver)
            applied.push(Tr.tr("Power Saver"));
        else if (profile === PowerProfile.Balanced)
            applied.push(Tr.tr("Balanced"));
        else if (profile === PowerProfile.Performance)
            applied.push(Tr.tr("Performance"));

        if (rate === "auto")
            applied.push(Tr.tr("lowest Hz"));
        else if (rate === "restore")
            applied.push(Tr.tr("original Hz"));
        else if (rate)
            applied.push(`${rate}Hz`);

        const names = {
            disableAnimations: Tr.tr("animations"),
            disableBlur: Tr.tr("blur"),
            disableRounding: Tr.tr("rounding"),
            disableShadows: Tr.tr("shadows")
        };
        for (const key of root.effectKeys) {
            if (effects[key] === "disable")
                applied.push(Tr.tr("no %1").arg(names[key]));
            else if (effects[key] === "enable")
                applied.push(Tr.tr("%1 on").arg(names[key]));
        }
        return applied;
    }

    function toastApplied(title: string, applied: list<string>): void {
        if (GlobalConfig.utilities.toasts.chargingChanged && applied.length > 0)
            Toaster.toast(title, Tr.tr("Applied: %1").arg(applied.join(", ")), "battery_saver");
    }

    function saveOriginalSettings(): void {
        root.originalProfile = PowerProfiles.profile;
        for (const monitor of Hypr.monitors.values) {
            const data = monitor.lastIpcObject;
            if (data && (data.refreshRate ?? 0) > 65)
                root.originalSettings.refreshRates[data.name] = data.refreshRate;
        }
    }

    function handleUnpluggedState(silent: bool): void {
        const config = PowerConfig.onUnplugged;

        if (!root.settingsModified)
            root.saveOriginalSettings();

        const applied = root.applyActions(config, -1);
        root.settingsModified = true;
        if (!silent)
            root.toastApplied(Tr.tr("On battery"), applied);

        root.currentThresholdIndex = -1;
        if (config.evaluateThresholds)
            root.evaluateThresholds();

        verifyRateTimer.restart();
    }

    function evaluateThresholds(): void {
        if (!UPower.onBattery || !root.powerManagementEnabled)
            return;

        const p = UPower.displayDevice.percentage * 100;

        let targetThresholdIndex = -1;
        for (let i = 0; i < root.powerThresholds.length; i++) {
            if (p <= root.powerThresholds[i].level) {
                targetThresholdIndex = i;
                break;
            }
        }

        if (targetThresholdIndex !== root.currentThresholdIndex) {
            root.currentThresholdIndex = targetThresholdIndex;

            if (targetThresholdIndex >= 0)
                root.applyThreshold(root.powerThresholds[targetThresholdIndex]);
        }
    }

    function applyThreshold(threshold): void {
        if (!root.settingsModified)
            root.saveOriginalSettings();

        const applied = root.applyActions(threshold, -1);
        root.settingsModified = true;
        root.toastApplied(Tr.tr("Battery saving active"), applied);
    }

    function handleChargingState(silent: bool): void {
        const applied = root.applyActions(PowerConfig.onCharging, PowerProfile.Balanced);

        root.settingsModified = false;
        root.originalProfile = -1;
        root.currentThresholdIndex = -1;
        if (!silent)
            root.toastApplied(Tr.tr("Plugged in"), applied);

        verifyRateTimer.restart();
    }

    function reapplyCurrent(): void {
        if (!root.powerManagementEnabled)
            return;

        const behaviour = root.behaviourFor(PowerProfiles.profile);
        if (behaviour) {
            root.applyActions({
                setPowerProfile: "",
                setRefreshRate: behaviour.setRefreshRate,
                disableAnimations: behaviour.disableAnimations,
                disableBlur: behaviour.disableBlur,
                disableRounding: behaviour.disableRounding,
                disableShadows: behaviour.disableShadows
            }, -1);
        }

        if (UPower.onBattery && root.currentThresholdIndex >= 0)
            root.applyActions(root.powerThresholds[root.currentThresholdIndex], -1);
    }

    function applyCurrentState(): void {
        if (root.initialised || !root.powerManagementEnabled || !UPower.displayDevice.ready)
            return;

        root.initialised = true;

        if (UPower.onBattery) {
            if (!root.settingsModified)
                root.saveOriginalSettings();
            root.settingsModified = true;
            root.currentThresholdIndex = -1;
            const cfg = PowerConfig.onUnplugged;
            if (root.hasValue(cfg.setPowerProfile)) {
                const targetProf = root.profileFromName(cfg.setPowerProfile);
                if (targetProf >= 0 && PowerProfiles.profile !== targetProf) {
                    root.expectedProfile = targetProf;
                    PowerProfiles.profile = targetProf;
                }
            }
        } else {
            const cfg = PowerConfig.onCharging;
            if (root.hasValue(cfg.setPowerProfile)) {
                const targetProf = root.profileFromName(cfg.setPowerProfile);
                if (targetProf >= 0 && PowerProfiles.profile !== targetProf) {
                    root.expectedProfile = targetProf;
                    PowerProfiles.profile = targetProf;
                }
            }
        }

        root.reapplyCurrent();
        root.evaluateThresholds();
    }

    onPowerManagementEnabledChanged: {
        root.initialised = false;
        startupTimer.restart();
    }

    Component.onCompleted: startupTimer.start()

    Connections {
        function onOnBatteryChanged(): void {
            if (!UPower.displayDevice.ready)
                return;

            if (UPower.onBattery) {
                if (GlobalConfig.utilities.toasts.chargingChanged)
                    Toaster.toast(Tr.tr("Charger unplugged"), Tr.tr("Battery is discharging"), "power_off");
                root.handleBatteryWarnings();

                if (root.powerManagementEnabled)
                    root.handleUnpluggedState(false);
            } else {
                if (GlobalConfig.utilities.toasts.chargingChanged)
                    Toaster.toast(Tr.tr("Charger plugged in"), Tr.tr("Battery is charging"), "power");
                root.lastPercentage = 100;
                root.cancelShellShutdown();
                root.shutdownFired = false;

                if (root.powerManagementEnabled)
                    root.handleChargingState(false);
            }
        }

        target: UPower
    }

    Connections {
        function onReadyChanged(): void {
            if (!UPower.displayDevice.ready)
                return;
            root.handleBatteryWarnings();
            root.applyDesktopDefault();
            startupTimer.restart();
        }

        target: UPower.displayDevice
    }

    Connections {
        function onPercentageChanged(): void {
            if (!UPower.displayDevice.ready)
                return;
            root.handleBatteryWarnings();
        }

        target: UPower.displayDevice
    }

    Connections {
        function onProfileChanged(): void {
            const expected = root.expectedProfile;
            root.expectedProfile = -1;
            if (PowerProfiles.profile === expected)
                return;

            const behaviour = root.behaviourFor(PowerProfiles.profile);
            if (!behaviour)
                return;

            const applied = root.applyActions({
                setPowerProfile: "",
                setRefreshRate: behaviour.setRefreshRate,
                disableAnimations: behaviour.disableAnimations,
                disableBlur: behaviour.disableBlur,
                disableRounding: behaviour.disableRounding,
                disableShadows: behaviour.disableShadows
            }, -1);
            root.toastApplied(root.describe(PowerProfiles.profile, "", {})[0] ?? "", applied);
        }

        target: PowerProfiles
    }

    Timer {
        id: shutdownTimer

        interval: 1000
        repeat: true
        onTriggered: {
            root.shutdownRemaining--;
            if (root.shutdownRemaining === 30 || root.shutdownRemaining === 10)
                root.warnShutdown(root.shutdownRemaining);

            if (root.shutdownRemaining <= 0) {
                shutdownTimer.stop();
                root.shutdownFired = true;
                root.runShutdown();
            }
        }
    }

    function runShutdown(): void {
        Quickshell.execDetached(["caelestia", "shell", "-k"]);
    }

    Timer {
        id: startupTimer

        interval: 1500
        onTriggered: root.applyCurrentState()
    }

    Connections {
        function onConfigReloaded(): void {
            reapplyTimer.restart();
        }

        target: Hypr
    }

    Timer {
        id: reapplyTimer

        interval: 1000
        onTriggered: root.reapplyCurrent()
    }

    Timer {
        id: verifyRateTimer

        interval: 800
        onTriggered: {
            if (!root.powerManagementEnabled)
                return;

            if (UPower.onBattery) {
                root.applyActions(PowerConfig.onUnplugged, -1);
                if (root.currentThresholdIndex >= 0)
                    root.applyActions(root.powerThresholds[root.currentThresholdIndex], -1);
            } else {
                root.applyActions(PowerConfig.onCharging, PowerProfile.Balanced);
            }
        }
    }
    Timer {
        id: hibernateTimer

        interval: 5000
        onTriggered: SessionManager.hibernate()
    }
}
