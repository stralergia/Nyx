pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property bool active
    required property string windowListRaw
    required property bool allowRestoreToken

    signal accepted(string result)
    signal cancelled()

    property int currentTab: 0 // 0: Displays, 1: Windows, 2: Region
    property string selectedType: "" // "screen", "window", "region"
    property string selectedId: ""
    property string selectedLabel: ""
    property bool rememberChoice: false

    property real openProg: root.active ? 1 : 0
    Behavior on openProg {
        Anim {
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Tokens.anim.curves.expressiveDefaultSpatial
        }
    }

    readonly property var parsedWindows: {
        const raw = root.windowListRaw ?? "";
        if (!raw)
            return [];

        const hasHa = raw.includes("[HA>]");
        const entries = raw.split(hasHa ? "[HA>]" : "[HE>]").filter(e => e.length > 0);
        const list = [];
        for (const entry of entries) {
            const parts = entry.split("[HC>]");
            if (parts.length < 2)
                continue;
            const id = parts[0].trim();
            const rest = parts[1].split("[HT>]");
            const appClass = rest[0] ?? "Window";
            const titleAndAddr = rest[1] ?? appClass;
            const title = hasHa ? titleAndAddr.split("[HE>]")[0] : titleAndAddr;
            list.push({ id, appClass, title });
        }
        return list;
    }

    onActiveChanged: {
        if (root.active) {
            root.currentTab = 0;
            root.rememberChoice = false;
            const firstScreen = Quickshell.screens[0];
            if (firstScreen) {
                root.selectedType = "screen";
                root.selectedId = firstScreen.name;
                root.selectedLabel = `${firstScreen.name} (${firstScreen.width}×${firstScreen.height})`;
            } else {
                root.selectedType = "";
                root.selectedId = "";
                root.selectedLabel = "";
            }
            root.forceActiveFocus();
        }
    }

    function submitSelection(): void {
        if (!root.selectedType || !root.selectedId)
            return;

        const flags = root.rememberChoice ? "r" : "";
        root.accepted(`[SELECTION]${flags}/${root.selectedType}:${root.selectedId}`);
    }

    Keys.onEscapePressed: root.cancelled()
    Keys.onReturnPressed: root.submitSelection()
    Keys.onEnterPressed: root.submitSelection()

    // Arka plan karartma
    Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: 0.55 * root.openProg

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancelled()
        }
    }

    // Ana M3 Pencere Kartı
    StyledRect {
        id: card

        anchors.centerIn: parent
        width: Math.min(860, root.width - Tokens.padding.large * 2)
        height: Math.min(580, root.height - Tokens.padding.large * 2)

        color: Colours.palette.m3surfaceContainer
        radius: Tokens.rounding.extraLarge
        border.width: 1
        border.color: Colours.palette.m3outlineVariant

        opacity: root.openProg
        scale: 0.94 + 0.06 * root.openProg

        // Kartın içindeki boşluklara tıklanınca arka planın pencereyi kapatmasını engeller
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            // 1. ÜST BAŞLIK + M3 SEKME SEÇİCİ
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledRect {
                    implicitWidth: 42
                    implicitHeight: 42
                    radius: Tokens.rounding.medium
                    color: Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: root.currentTab === 0 ? "monitor" : (root.currentTab === 1 ? "web_asset" : "crop")
                        color: Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.medium
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: qsTr("Share Screen or Window")
                        font: Tokens.font.title.medium
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        text: qsTr("Choose what you want to broadcast")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                // M3 Segmented Tab Bar
                StyledRect {
                    implicitWidth: tabRow.implicitWidth + 8
                    implicitHeight: 40
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3surfaceContainerHigh

                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            model: [
                                { label: qsTr("Displays"), icon: "monitor" },
                                { label: qsTr("Windows"), icon: "web_asset" },
                                { label: qsTr("Region"), icon: "crop" }
                            ]

                            delegate: StyledRect {
                                required property var modelData
                                required property int index

                                readonly property bool isCurrent: root.currentTab === index

                                implicitWidth: tabInner.implicitWidth + 24
                                implicitHeight: 32
                                radius: Tokens.rounding.full
                                color: isCurrent ? Colours.palette.m3secondaryContainer : (tabMouse.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent")

                                Row {
                                    id: tabInner
                                    anchors.centerIn: parent
                                    spacing: 6

                                    MaterialIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.icon
                                        fontStyle: Tokens.font.icon.small
                                        color: isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        font: Tokens.font.label.large
                                        color: isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                    }
                                }

                                MouseArea {
                                    id: tabMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentTab = index;
                                        if (index === 0) {
                                            const s = Quickshell.screens[0];
                                            if (s) {
                                                root.selectedType = "screen";
                                                root.selectedId = s.name;
                                                root.selectedLabel = `${s.name} (${s.width}×${s.height})`;
                                            }
                                        } else if (index === 1) {
                                            root.selectedType = "";
                                            root.selectedId = "";
                                            root.selectedLabel = "";
                                        } else if (index === 2) {
                                            root.selectedType = "region";
                                            root.selectedId = "slurp";
                                            root.selectedLabel = qsTr("Custom screen region");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 2. ORTA CANLI ÖNİZLEME ALANI
            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.rounding.large
                color: Colours.palette.m3surfaceContainerLowest
                border.width: 1
                border.color: Colours.palette.m3outlineVariant
                clip: true

                // SEKME 0: EKRANLAR
                Row {
                    visible: root.currentTab === 0
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.large

                    Repeater {
                        model: Quickshell.screens

                        delegate: Item {
                            required property ShellScreen modelData

                            readonly property bool selected: root.selectedType === "screen" && root.selectedId === modelData.name
                            readonly property real aspect: modelData.width / Math.max(1, modelData.height)
                            readonly property int boxH: 260
                            readonly property int boxW: Math.min(440, Math.round(boxH * aspect))

                            width: boxW + 12
                            height: boxH + 12

                            StyledRect {
                                anchors.fill: parent
                                radius: Tokens.rounding.medium
                                color: selected ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
                                border.width: selected ? 2 : 1
                                border.color: selected ? Colours.palette.m3primary : (screenMouse.containsMouse ? Colours.palette.m3outline : Colours.palette.m3outlineVariant)
                                clip: true

                                Item {
                                    anchors.fill: parent
                                    anchors.margins: 6

                                    ScreencopyView {
                                        anchors.fill: parent
                                        captureSource: modelData
                                        live: root.active && root.currentTab === 0
                                    }

                                    StyledRect {
                                        visible: selected
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: Colours.palette.m3primary

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: "check"
                                            fontStyle: Tokens.font.icon.small
                                            color: Colours.palette.m3onPrimary
                                        }
                                    }

                                    StyledRect {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 8
                                        width: badgeRow.implicitWidth + 16
                                        height: 26
                                        radius: Tokens.rounding.full
                                        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.92)

                                        Row {
                                            id: badgeRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            StyledText {
                                                text: modelData.name
                                                font: Tokens.font.label.large
                                                color: Colours.palette.m3primary
                                            }

                                            StyledText {
                                                text: `· ${modelData.width} × ${modelData.height}`
                                                font: Tokens.font.label.small
                                                color: Colours.palette.m3onSurface
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: screenMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedType = "screen";
                                        root.selectedId = modelData.name;
                                        root.selectedLabel = `${modelData.name} (${modelData.width}×${modelData.height})`;
                                    }
                                }
                            }
                        }
                    }
                }

                // SEKME 1: PENCERELER
                Item {
                    visible: root.currentTab === 1
                    anchors.fill: parent

                    StyledText {
                        visible: root.parsedWindows.length === 0
                        anchors.centerIn: parent
                        text: qsTr("No shareable windows reported by portal")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    GridView {
                        visible: root.parsedWindows.length > 0
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        cellWidth: Math.floor(width / 2)
                        cellHeight: 84
                        clip: true

                        model: root.parsedWindows

                        delegate: Item {
                            required property var modelData

                            readonly property bool selected: root.selectedType === "window" && root.selectedId === modelData.id

                            width: GridView.view.cellWidth
                            height: GridView.view.cellHeight

                            StyledRect {
                                anchors.fill: parent
                                anchors.margins: 5
                                radius: Tokens.rounding.medium
                                color: selected ? Colours.palette.m3secondaryContainer : (winMouse.containsMouse ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainer)
                                border.width: selected ? 2 : 1
                                border.color: selected ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    Image {
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                        source: Quickshell.iconPath(modelData.appClass.toLowerCase(), true)
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.title
                                            elide: Text.ElideRight
                                            font: Tokens.font.title.small
                                            color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.appClass
                                            elide: Text.ElideRight
                                            font: Tokens.font.body.small
                                            color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                        }
                                    }

                                    StyledRect {
                                        visible: selected
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: Colours.palette.m3primary

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: "check"
                                            fontStyle: Tokens.font.icon.small
                                            color: Colours.palette.m3onPrimary
                                        }
                                    }
                                }

                                MouseArea {
                                    id: winMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedType = "window";
                                        root.selectedId = modelData.id;
                                        root.selectedLabel = `${modelData.appClass} — ${modelData.title}`;
                                    }
                                }
                            }
                        }
                    }
                }

                // SEKME 2: BÖLGE SEÇİMİ (Slurp)
                Item {
                    visible: root.currentTab === 2
                    anchors.fill: parent

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submitSelection()
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.medium

                        StyledRect {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 64
                            implicitHeight: 64
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3primaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "crop_free"
                                fontStyle: Tokens.font.icon.large
                                color: Colours.palette.m3onPrimaryContainer
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Select a custom area on your screen")
                            font: Tokens.font.title.small
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Click here or press Share to select a region with slurp")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }

            // 3. SEÇİM DURUM ÇUBUĞU
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: Tokens.rounding.medium
                color: Colours.palette.m3surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialIcon {
                        text: root.selectedId !== "" ? "check_circle" : "info"
                        fontStyle: Tokens.font.icon.small
                        color: root.selectedId !== "" ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.selectedLabel !== "" ? root.selectedLabel : qsTr("Click a display or window above to select it")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            // 4. ALT KONTROL SATIRI (Remember choice + Cancel / Share)
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                RowLayout {
                    visible: root.allowRestoreToken
                    spacing: 8

                    StyledSwitch {
                        checked: root.rememberChoice
                        onToggled: root.rememberChoice = checked
                    }

                    StyledText {
                        text: qsTr("Remember this choice")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurface
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    text: qsTr("Cancel")
                    onClicked: root.cancelled()
                }

                IconTextButton {
                    text: qsTr("Share")
                    icon: "screen_share"
                    enabled: root.selectedId !== ""
                    onClicked: root.submitSelection()
                }
            }
        }
    }
}
