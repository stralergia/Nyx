pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    function signed(value: real): string {
        const rounded = Math.round(value * 100) / 100;
        return (rounded > 0 ? "+" : "") + rounded.toFixed(2);
    }

    function factor(value: real): string {
        return (Math.round(value * 100) / 100).toFixed(2);
    }

    readonly property list<MenuItem> scrollTypeItems: [
        MenuItem {
            text: Tr.tr("Natural")
        },
        MenuItem {
            text: Tr.tr("Reversed")
        }
    ]

    title: Tr.tr("Input")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Mouse
        SectionHeader {
            first: true
            text: Tr.tr("Mouse")
        }

        SliderRow {
            first: true
            icon: "mouse"
            label: Tr.tr("Sensitivity")
            valueLabel: root.signed(InputSettings.sensitivity)
            value: (InputSettings.sensitivity + 1.0) / 2.0
            onMoved: v => {
                const mapped = (v * 2.0) - 1.0;
                const stepped = Math.round(mapped * 20) / 20;
                InputSettings.set(InputSettings.sensitivityKey, stepped);
            }
        }

        ToggleRow {
            text: Tr.tr("Acceleration")
            subtext: Tr.tr("Flat pointer movement when off, adaptive when on")
            checked: InputSettings.accelProfile !== "flat"
            onToggled: InputSettings.setAccel(checked)
        }

        SliderRow {
            last: true
            icon: "swap_vert"
            label: Tr.tr("Scroll sensitivity")
            valueLabel: root.factor(InputSettings.scrollFactor)
            value: (InputSettings.scrollFactor - 0.1) / 2.9
            onMoved: v => {
                const mapped = 0.1 + (v * 2.9);
                const stepped = Math.round(mapped * 20) / 20;
                InputSettings.set(InputSettings.scrollFactorKey, stepped);
            }
        }

        // Touchpad
        SectionHeader {
            text: Tr.tr("Touchpad")
        }

        SliderRow {
            first: true
            icon: "touch_app"
            label: Tr.tr("Scroll sensitivity")
            valueLabel: root.factor(InputSettings.touchpadScrollFactor)
            value: (InputSettings.touchpadScrollFactor - 0.1) / 2.9
            onMoved: v => {
                const mapped = 0.1 + (v * 2.9);
                const stepped = Math.round(mapped * 20) / 20;
                InputSettings.set(InputSettings.touchpadScrollFactorKey, stepped);
            }
        }

        SelectRow {
            last: true
            label: Tr.tr("Scrolling type")
            subtext: Tr.tr("Natural follows your fingers, reversed is the traditional direction")
            menuItems: root.scrollTypeItems
            active: root.scrollTypeItems[InputSettings.naturalScroll ? 0 : 1]
            onSelected: item => InputSettings.set(InputSettings.naturalScrollKey, root.scrollTypeItems.indexOf(item) === 0)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            text: Tr.tr("Written to ~/.config/caelestia/hypr-user.lua and applied right away, so they survive a restart. Settings left alone use your Hyprland config.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
