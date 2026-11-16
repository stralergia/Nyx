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

    title: Tr.tr("Cursor theme")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Available Themes")
        }

        Repeater {
            model: InputSettings.cursorThemes

            delegate: ItemRow {
                required property string modelData

                first: index === 0
                last: index === InputSettings.cursorThemes.length - 1
                icon: "arrow_selector_tool"
                label: modelData
                subtext: InputSettings.cursorTheme === modelData ? Tr.tr("Active theme") : ""

                onClicked: {
                    InputSettings.setCursor(modelData, InputSettings.cursorSize);
                    stack.pop();
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.spacing.extraLarge * 4
        }
    }
}
