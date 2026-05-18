import "../shared"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: "notes.md"
    property string body: ""
    property string file: ""
    property int index: 0
    property int count: 1
    property bool editing: false
    readonly property int lineCount: Math.max(1, body.split("\n").length + (editing ? 1 : 0))
    readonly property int longestLine: {
        const lines = body.split("\n");
        let longest = title.length + 10;
        for (let i = 0; i < lines.length; i++) longest = Math.max(longest, lines[i].length)
        return longest;
    }

    signal previous()
    signal next()
    signal edit()
    signal save(string file, string body)

    width: Math.min(680, Math.max(320, longestLine * 7 + 72))
    height: Math.min(760, Math.max(150, lineCount * 18 + 96))
    radius: 8
    color: Theme.background
    border.color: Theme.surfaceAlt
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [{
                    "icon": "‹",
                    "action": "prev"
                }, {
                    "icon": "›",
                    "action": "next"
                }, {
                    "icon": root.editing ? "󰈈" : "󰏫",
                    "action": "edit"
                }, {
                    "icon": root.editing ? "󰆓" : "",
                    "action": "save"
                }]

                Rectangle {
                    width: modelData.icon === "" ? 0 : 30
                    height: 30
                    visible: modelData.icon !== ""
                    radius: 5
                    color: (root.editing && (modelData.action === "prev" || modelData.action === "next")) ? "transparent" : noteMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                    opacity: (root.editing && (modelData.action === "prev" || modelData.action === "next")) ? 0.35 : 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: noteMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.editing && (modelData.action === "prev" || modelData.action === "next"))
                                return ;

                            if (modelData.action === "prev")
                                root.previous();
                            else if (modelData.action === "next")
                                root.next();
                            else if (modelData.action === "save")
                                root.save(root.file, editor.text);
                            else
                                root.editing = !root.editing;
                        }
                    }

                }

            }

            Text {
                Layout.fillWidth: true
                text: root.title + "  " + (root.index + 1) + "/" + root.count
                color: Theme.blue
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 6
            color: Theme.surface
            border.color: Theme.surfaceAlt
            border.width: 1
            clip: true

            TextEdit {
                id: editor

                anchors.fill: parent
                anchors.margins: 12
                text: root.body
                readOnly: !root.editing
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                textFormat: root.editing ? TextEdit.PlainText : TextEdit.MarkdownText
                color: Theme.foreground
                selectedTextColor: Theme.background
                selectionColor: Theme.blue
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

        }

    }

}
