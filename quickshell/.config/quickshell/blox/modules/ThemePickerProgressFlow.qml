import "."
import "../shared"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    required property ThemePickerController controller

    visible: controller.modalKind === "progress" || controller.modalKind === "guide"
    Layout.fillWidth: true
    spacing: 12

    ScrollView {
        visible: controller.modalKind === "progress"
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(420, progressGrid.implicitHeight)
        contentWidth: availableWidth
        clip: true

        GridLayout {
            id: progressGrid

            width: parent.width
            columns: 1
            columnSpacing: 14
            rowSpacing: 8

            Repeater {
                model: controller.applyProgressRows

                RowLayout {
                    required property var modelData

                    Layout.preferredWidth: progressGrid.width

                    Text {
                        text: modelData.target.replace("cursor_editor", "cursor")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        Layout.preferredWidth: 150
                    }

                    Text {
                        text: modelData.message
                        color: modelData.state === "failed" || modelData.state === "manual" ? Theme.red : modelData.state === "restart" ? Theme.yellow : modelData.state === "applied" ? Theme.green : Theme.blue
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    BloxButton {
                        visible: modelData.state === "manual"
                        text: "Guide"
                        onClicked: {
                            controller.guideTarget = modelData.target;
                            controller.modalKind = "guide";
                        }
                    }

                }

            }

        }

    }

    ColumnLayout {
        visible: controller.modalKind === "guide"
        Layout.fillWidth: true

        Image {
            visible: controller.guideTarget === "stylus"
            Layout.fillWidth: true
            height: 180
            source: "../assets/stylus-import.png"
            fillMode: Image.PreserveAspectFit
        }

        Text {
            Layout.fillWidth: true
            text: controller.guideTarget === "obsidian" ? "1. Install and select the Minimal theme, then enable the Style Settings plugin.\n2. Open Style Settings in its own pane and choose Import.\n3. Select the generated style-settings.json file and confirm the import." : "1. Open the Stylus extension dashboard.\n2. Choose Import and select the generated blox-system.user.css file.\n3. Replace the previous Blox System Theme entry, then enable it."
            color: Theme.foreground
            wrapMode: Text.Wrap
        }

        BloxButton {
            visible: controller.guideTarget === "stylus"
            Layout.alignment: Qt.AlignRight
            iconName: "download"
            text: "Download file"
            onClicked: controller.downloadGeneratedFile("stylus", "stylus/blox-system.user.css")
        }

    }

}
