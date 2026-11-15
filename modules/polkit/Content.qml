pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    property var flow: null

    readonly property bool awaitingInput: root.flow?.isResponseRequired ?? false
    readonly property bool verifying: root.flow !== null && !root.flow.isResponseRequired && !root.flow.isCompleted
    readonly property var identities: root.flow?.identities ?? []
    readonly property bool pickIdentity: root.identities.length > 1

    property string heldMessage
    property string heldIcon

    readonly property string notice: {
        if (!root.flow)
            return "";
        if (root.flow.supplementaryMessage !== "")
            return root.flow.supplementaryMessage;
        return root.flow.failed ? "Authentication failed" : "";
    }
    readonly property bool noticeIsError: root.flow?.failed || root.flow?.supplementaryIsError || false
    readonly property string actionIcon: root.heldIcon !== "" && Quickshell.hasThemeIcon(root.heldIcon) ? Quickshell.iconPath(root.heldIcon) : ""

    property real openProg: root.flow !== null ? 1 : 0

    readonly property int fullWidth: Math.min(380, root.width - Tokens.padding.extraLargeIncreased)
    readonly property int fullHeight: layout.implicitHeight + Tokens.padding.large * 3

    function submit(): void {
        if (!root.flow || root.flow.isCompleted)
            return;
        root.flow.submit(password.text);
        password.text = "";
    }

    function cancel(): void {
        root.flow?.cancelAuthenticationRequest();
    }

    onFlowChanged: {
        password.text = "";
        if (root.flow) {
            root.heldMessage = root.flow.message ?? "";
            root.heldIcon = root.flow.iconName ?? "";
            focusTimer.restart();
        }
    }

    focus: true
    Keys.onEscapePressed: root.cancel()

    Behavior on openProg {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Connections {
        function onIsResponseRequiredChanged(): void {
            if (root.awaitingInput)
                focusTimer.restart();
        }
        target: root.flow
    }

    Timer {
        id: focusTimer
        interval: 100
        onTriggered: password.forceActiveFocus()
    }

    // Arka plan karartması
    StyledRect {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.45 * root.openProg)

        MouseArea {
            anchors.fill: parent
        }
    }

    // Ortalanmış Material 3 Polkit Kartı
    StyledRect {
        id: card

        anchors.centerIn: parent
        width: root.fullWidth
        height: root.fullHeight
        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surface
        opacity: root.openProg
        scale: 0.94 + (0.06 * root.openProg)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
        }

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            width: parent.width - Tokens.padding.large * 3
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledRect {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: implicitHeight
                    implicitHeight: shield.implicitHeight + Tokens.padding.medium * 2
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        id: shield
                        anchors.centerIn: parent
                        visible: root.actionIcon === ""
                        text: "shield_lock"
                        color: Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.medium
                    }

                    Loader {
                        anchors.centerIn: parent
                        active: root.actionIcon !== ""
                        asynchronous: true
                        width: Math.round(parent.width * 0.55)
                        height: width

                        sourceComponent: ColouredIcon {
                            anchors.fill: parent
                            source: root.actionIcon
                            colour: Colours.palette.m3onSecondaryContainer
                            layer.enabled: root.heldIcon.endsWith("symbolic")
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: "Authentication required"
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.heldMessage
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.pickIdentity
                spacing: Tokens.spacing.small

                Repeater {
                    model: root.identities

                    TextButton {
                        id: identityButton
                        required property var modelData
                        readonly property bool selected: root.flow?.selectedIdentity === identityButton.modelData

                        text: identityButton.modelData.displayName || identityButton.modelData.string
                        type: TextButton.Tonal
                        isToggle: true
                        checked: identityButton.selected
                        onClicked: {
                            if (root.flow) {
                                root.flow.selectedIdentity = identityButton.modelData;
                                password.text = "";
                            }
                        }
                    }
                }
            }

            StyledTextField {
                id: password
                Layout.fillWidth: true
                placeholderText: root.flow?.inputPrompt || "Password"
                leadingIcon: "key"
                echoMode: (root.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
                enabled: root.awaitingInput
                onAccepted: root.submit()
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: -Tokens.spacing.extraSmall
                visible: text !== ""
                text: root.notice
                color: root.noticeIsError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Loader {
                    Layout.alignment: Qt.AlignVCenter
                    active: root.verifying
                    visible: active
                    sourceComponent: LoadingIndicator {
                        implicitSize: Math.round(Tokens.font.body.small.pointSize * 1.4)
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    type: TextButton.Text
                    text: "Cancel"
                    onClicked: root.cancel()
                }

                TextButton {
                    type: TextButton.Filled
                    text: "Authenticate"
                    disabled: root.verifying || !root.awaitingInput
                    onClicked: root.submit()
                }
            }
        }
    }
}
