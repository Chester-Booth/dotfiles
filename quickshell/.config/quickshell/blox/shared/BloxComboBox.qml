import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property var model: []
    property int currentIndex: 0
    readonly property string currentText: currentIndex >= 0 && currentIndex < model.length ? String(model[currentIndex]) : ""
    readonly property bool hovered: hover.hovered

    signal activated(int index)

    implicitHeight: 38
    implicitWidth: 132
    radius: 9
    color: tap.pressed || popup.visible ? Theme.surfaceAlt : hovered ? Theme.withAlpha(Theme.surfaceAlt, 0.72) : Theme.background
    border.color: activeFocus || popup.visible ? Theme.blue : Theme.border
    border.width: activeFocus || popup.visible ? 2 : 1
    activeFocusOnTab: enabled
    onVisibleChanged: {
        if (!visible)
            popup.close();

    }

    Text {
        anchors.left: parent.left
        anchors.right: indicator.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 11
        anchors.rightMargin: 8
        text: root.currentText
        color: Theme.foreground
        font.family: Theme.bodyFontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    Text {
        id: indicator

        anchors.right: parent.right
        anchors.rightMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        text: popup.visible ? "▴" : "▾"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        enabled: root.enabled
        onTapped: popup.open()
    }

    Popup {
        id: popup

        popupType: Popup.Item
        modal: false
        dim: false
        y: root.height + 5
        width: root.width
        height: Math.min(260, list.contentHeight + 8)
        padding: 4
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        contentItem: ListView {
            id: list

            clip: true
            model: root.model

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: list.width
                height: 36
                radius: 7
                color: optionHover.hovered || index === root.currentIndex ? Theme.surfaceAlt : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 10
                    text: modelData
                    color: index === root.currentIndex ? Theme.blue : Theme.foreground
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                HoverHandler {
                    id: optionHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        root.currentIndex = index;
                        root.activated(index);
                        popup.close();
                    }
                }

            }

        }

        background: Rectangle {
            radius: 9
            color: Theme.surface
            border.color: Theme.border
        }

    }

}
