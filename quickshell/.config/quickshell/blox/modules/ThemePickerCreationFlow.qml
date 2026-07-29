import "."
import "../shared"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    required property ThemePickerController controller

    function focusInitial() {
        if (controller.newFlowPage === "wallpaper")
            newWallpaperField.focusEditor(true);
        else
            newNameField.focusEditor(true);
    }

    visible: controller.modalKind === "new"
    Layout.fillWidth: true
    spacing: 12

    Label {
        visible: controller.modalKind === "new" && !controller.creationBusy
        text: "Name"
        color: Theme.foreground
        font.bold: true
    }

    BloxTextField {
        id: newNameField

        visible: controller.modalKind === "new" && !controller.creationBusy
        Layout.fillWidth: true
        placeholderText: "My Theme"
        text: controller.newThemeName
        onTextChanged: {
            controller.newThemeName = text;
            controller.newThemeId = controller.duplicateIdForName(text);
        }
        onAccepted: {
            if (controller.newThemeId.trim().length > 0 && controller.newThemeName.trim().length > 0)
                controller.startNewTheme(false);

        }
    }

    Label {
        visible: controller.modalKind === "new" && !controller.creationBusy && controller.newFlowPage === "wallpaper"
        text: "File Path"
        color: Theme.foreground
        font.bold: true
    }

    RowLayout {
        visible: controller.modalKind === "new" && !controller.creationBusy && controller.newFlowPage === "wallpaper"
        Layout.fillWidth: true

        BloxTextField {
            id: newWallpaperField

            Layout.fillWidth: true
            placeholderText: "/path/to/wallpaper"
            text: controller.newWallpaper
            onTextChanged: {
                controller.newWallpaper = text;
                controller.schedulePaletteRequest();
            }
        }

        BloxButton {
            text: "Browse"
            onClicked: controller.openWallpaperDialog("new")
        }

    }

    Label {
        visible: controller.modalKind === "new" && !controller.creationBusy && controller.newFlowPage === "wallpaper" && controller.newWallpaper.trim().length > 0
        text: "Base Colour Palette"
        color: Theme.foreground
        font.bold: true
    }

    BusyIndicator {
        visible: controller.modalKind === "new" && !controller.creationBusy && controller.paletteLoading
        running: visible
        Layout.alignment: Qt.AlignHCenter
    }

    Repeater {
        model: controller.modalKind === "new" && !controller.creationBusy && controller.newFlowPage === "wallpaper" ? controller.paletteOptions : []

        Rectangle {
            id: paletteRow

            required property var modelData

            Layout.fillWidth: true
            height: 46
            radius: 8
            color: Theme.background
            border.color: controller.generatorBackend === modelData.backend ? Theme.blue : Theme.border
            opacity: modelData.available ? 1 : 0.5

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: "transparent"
                    border.color: modelData.available ? Theme.blue : Theme.muted
                    border.width: 2

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        visible: controller.generatorBackend === modelData.backend
                        color: Theme.blue
                    }

                }

                Text {
                    text: modelData.backend === "matugen" ? "Matugen" : "Pywal"
                    color: Theme.foreground
                    font.family: Theme.bodyFontFamily
                    Layout.preferredWidth: 72
                }

                Repeater {
                    model: ["background", "surface", "accent", "danger", "success", "warning", "info", "mauve", "teal", "foreground"]

                    Rectangle {
                        required property string modelData

                        width: 24
                        height: 24
                        radius: 12
                        color: paletteRow.modelData.colours[modelData] || "transparent"
                        border.color: Theme.border
                    }

                }

            }

            TapHandler {
                enabled: modelData.available
                onTapped: controller.generatorBackend = modelData.backend
            }

        }

    }

    ColumnLayout {
        visible: controller.modalKind === "new" && controller.creationBusy
        Layout.fillWidth: true

        BusyIndicator {
            running: visible
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: controller.creationRequest && controller.creationRequest.wallpaper ? controller.creationRequest.backend + " — generating palette and theme" : "Creating blank theme"
            color: Theme.blue
        }

    }

}
