import "../shared"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property date baseDate: new Date()
    property int monthOffset: 0
    property date selectedDate: new Date()
    property var events: []
    property string eventsText: ""
    property string newEventTitle: ""

    signal selected(string day)
    signal addEvent(string day, string title)
    signal resetMonth()

    function shownDate() {
        return new Date(baseDate.getFullYear(), baseDate.getMonth() + monthOffset, 1);
    }

    function daysInMonth(date) {
        return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
    }

    function firstDay(date) {
        return new Date(date.getFullYear(), date.getMonth(), 1).getDay();
    }

    function isoDate(date) {
        const month = date.getMonth() + 1;
        const day = date.getDate();
        return date.getFullYear() + "-" + (month < 10 ? "0" + month : month) + "-" + (day < 10 ? "0" + day : day);
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function eventTime(line) {
        const match = line.match(/^\s*([0-9]{1,2}:[0-9]{2})\s+(.*)$/);
        return match ? match[1] : "";
    }

    function eventTitle(line) {
        const match = line.match(/^\s*([0-9]{1,2}:[0-9]{2})\s+(.*)$/);
        if (match)
            return match[2];

        return line.replace(/^[A-Z][a-z][a-z]\s+[A-Z][a-z][a-z]\s+[0-9]{1,2}\s*/, "");
    }

    width: 420
    height: 520
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

            Rectangle {
                width: 30
                height: 30
                radius: 5
                color: prevMouse.containsMouse ? Theme.surfaceAlt : Theme.surface

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                }

                MouseArea {
                    id: prevMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.monthOffset--
                }

            }

            Text {
                Layout.fillWidth: true
                text: Qt.formatDate(root.shownDate(), "MMMM yyyy")
                color: Theme.blue
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                horizontalAlignment: Text.AlignHCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.monthOffset = 0;
                        root.selectedDate = root.baseDate;
                        root.resetMonth();
                    }
                }

            }

            Rectangle {
                width: 30
                height: 30
                radius: 5
                color: nextMouse.containsMouse ? Theme.surfaceAlt : Theme.surface

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                }

                MouseArea {
                    id: nextMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.monthOffset++
                }

            }

        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

                Text {
                    Layout.fillWidth: true
                    text: modelData
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                }

            }

            Repeater {
                model: 42

                Rectangle {
                    readonly property date monthDate: root.shownDate()
                    readonly property int dayNumber: index - root.firstDay(monthDate) + 1
                    readonly property bool inMonth: dayNumber >= 1 && dayNumber <= root.daysInMonth(monthDate)
                    readonly property date cellDate: new Date(monthDate.getFullYear(), monthDate.getMonth(), Math.max(1, dayNumber))
                    readonly property bool today: inMonth && root.sameDay(cellDate, root.baseDate)
                    readonly property bool selected: inMonth && root.sameDay(cellDate, root.selectedDate)

                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 5
                    color: selected ? Theme.blue : today ? Theme.surfaceAlt : dayMouse.containsMouse && inMonth ? Theme.surfaceAlt : Theme.surface
                    opacity: inMonth ? 1 : 0.25

                    Text {
                        anchors.centerIn: parent
                        text: parent.inMonth ? parent.dayNumber : ""
                        color: parent.selected ? Theme.background : parent.today ? Theme.yellow : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: parent.today || parent.selected
                    }

                    MouseArea {
                        id: dayMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.inMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!parent.inMonth)
                                return ;

                            root.selectedDate = parent.cellDate;
                            root.selected(root.isoDate(parent.cellDate));
                        }
                    }

                }

            }

        }

        Text {
            Layout.fillWidth: true
            text: Qt.formatDate(root.selectedDate, "dddd dd MMM")
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                visible: root.events.length === 0
                text: root.eventsText
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: root.events

                Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: 6
                    color: eventMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                    border.color: Theme.surfaceAlt
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 42
                            text: root.eventTime(modelData) || "•"
                            color: Theme.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.eventTitle(modelData)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                    }

                    MouseArea {
                        id: eventMouse

                        anchors.fill: parent
                        hoverEnabled: true
                    }

                }

            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: 5
                color: Theme.surface
                border.color: Theme.surfaceAlt
                border.width: 1

                TextInput {
                    id: eventInput

                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    text: root.newEventTitle
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    onTextChanged: root.newEventTitle = text
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: eventInput.text.length === 0
                    text: "New event title"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

            }

            Rectangle {
                width: 42
                height: 34
                radius: 5
                color: addMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                border.color: Theme.surfaceAlt
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: Theme.green
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                }

                MouseArea {
                    id: addMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.addEvent(root.isoDate(root.selectedDate), root.newEventTitle);
                        root.newEventTitle = "";
                    }
                }

            }

        }

    }

}
