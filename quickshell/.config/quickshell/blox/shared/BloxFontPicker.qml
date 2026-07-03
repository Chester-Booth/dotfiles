import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property string value: ""
    property var families: []
    property string query: ""

    signal accepted(string family)

    function filteredFamilies() {
        const needle = query.trim().toLowerCase();
        const matches = needle ? families.filter((family) => {
            return String(family).toLowerCase().indexOf(needle) >= 0;
        }) : families;
        return matches.slice(0, 100);
    }

    function choose(family) {
        editor.text = family;
        query = family;
        accepted(family);
        popup.close();
    }

    function openList() {
        editor.text = value;
        query = "";
        editor.forceActiveFocus();
        popup.open();
    }

    implicitHeight: 40
    implicitWidth: 250
    radius: 9
    color: Theme.background
    border.color: editor.activeFocus || popup.visible ? Theme.blue : hover.hovered ? Theme.withAlpha(Theme.foreground, 0.34) : Theme.border
    border.width: editor.activeFocus || popup.visible ? 2 : 1
    onVisibleChanged: {
        if (!visible)
            popup.close();

    }
    onValueChanged: {
        if (!editor.activeFocus)
            editor.text = value;

    }

    TextInput {
        id: editor

        anchors.left: parent.left
        anchors.right: indicator.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 11
        anchors.rightMargin: 8
        text: root.value
        color: Theme.foreground
        selectionColor: Theme.withAlpha(Theme.blue, 0.5)
        selectedTextColor: Theme.foreground
        font.family: text.length > 0 ? text : Theme.bodyFontFamily
        font.pixelSize: 13
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true
        clip: true
        onTextChanged: {
            if (!activeFocus)
                cursorPosition = 0;

        }
        onTextEdited: {
            root.query = text;
            if (!popup.visible)
                popup.open();

        }
        onEditingFinished: {
            const family = text.trim();
            if (family.length > 0)
                root.accepted(family);

        }
        Keys.onDownPressed: popup.open()
    }

    Text {
        id: indicator

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 34
        text: popup.visible ? "▴" : "▾"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openList()
        }

    }

    HoverHandler {
        id: hover

        cursorShape: Qt.IBeamCursor
    }

    TapHandler {
        onTapped: root.openList()
    }

    Popup {
        id: popup

        readonly property real fieldY: root.mapToItem(null, 0, 0).y
        readonly property real availableAbove: Math.max(100, fieldY - 12)
        readonly property real availableBelow: Math.max(100, (root.Window.window ? root.Window.window.height : 860) - fieldY - root.height - 12)
        readonly property bool opensBelow: availableAbove < Math.min(360, fontList.contentHeight + 8) && availableBelow > availableAbove

        popupType: Popup.Item
        modal: false
        dim: false
        y: opensBelow ? root.height + 5 : -height - 5
        width: Math.max(root.width, 330)
        height: Math.min(360, fontList.contentHeight + 8, opensBelow ? availableBelow : availableAbove)
        padding: 4
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        contentItem: ListView {
            id: fontList

            clip: true
            model: popup.visible ? root.filteredFamilies() : []

            delegate: Rectangle {
                required property string modelData

                width: fontList.width
                height: 42
                radius: 7
                color: fontHover.hovered || modelData === root.value ? Theme.surfaceAlt : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 11
                    text: modelData
                    color: modelData === root.value ? Theme.blue : Theme.foreground
                    font.family: modelData
                    font.pixelSize: 15
                    elide: Text.ElideRight
                }

                HoverHandler {
                    id: fontHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.choose(modelData)
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
