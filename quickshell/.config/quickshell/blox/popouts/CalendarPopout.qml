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
    property string eventsError: ""
    property bool eventsLoading: false
    property string newEventTitle: ""
    property int addRevision: 0
    property bool addBusy: false
    property string addError: ""
    readonly property int visibleEventCount: Math.max(1, events.length)
    readonly property int eventRowHeight: 42
    readonly property int eventRowSpacing: 6
    readonly property int contentMargins: 28
    readonly property int contentSpacing: 40
    readonly property int headerHeight: 30
    readonly property int monthGridHeight: 246
    readonly property int selectedDateHeight: 15
    readonly property int inputHeight: 34
    readonly property int addStatusHeight: addError.length > 0 ? 18 : 0
    readonly property int agendaHeight: root.events.length === 0 ? 18 : visibleEventCount * eventRowHeight + Math.max(0, visibleEventCount - 1) * eventRowSpacing
    readonly property int desiredHeight: contentMargins + contentSpacing + headerHeight + monthGridHeight + selectedDateHeight + agendaHeight + inputHeight + addStatusHeight

    signal selected(string day)
    signal addEvent(string day, string title)
    signal resetMonth()
    signal openEvent(string title)
    signal focusRequested()

    function shownDate() {
        return new Date(baseDate.getFullYear(), baseDate.getMonth() + monthOffset, 1);
    }

    function daysInMonth(date) {
        return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
    }

    function firstDay(date) {
        return (new Date(date.getFullYear(), date.getMonth(), 1).getDay() + 6) % 7;
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

    onAddRevisionChanged: {
        if (addRevision > 0)
            newEventTitle = "";

    }
    width: 420
    height: Math.max(420, desiredHeight)
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
                border.color: Theme.surfaceAlt
                border.width: 1

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
                font.family: Theme.bodyFontFamily
                font.pixelSize: 16
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
                border.color: Theme.surfaceAlt
                border.width: 1

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
            id: monthGrid

            readonly property real cellWidth: (width - columnSpacing * 6) / 7

            Layout.fillWidth: true
            columns: 7
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: monthGrid.cellWidth
                    text: modelData
                    color: Theme.muted
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 12
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
                    Layout.preferredWidth: monthGrid.cellWidth
                    Layout.preferredHeight: 34
                    radius: 5
                    color: selected ? Theme.blue : today ? Theme.surfaceAlt : dayMouse.containsMouse && inMonth ? Theme.surfaceAlt : Theme.surface
                    opacity: inMonth ? 1 : 0.25

                    Text {
                        anchors.centerIn: parent
                        text: parent.inMonth ? parent.dayNumber : ""
                        color: parent.selected ? Theme.background : parent.today ? Theme.yellow : Theme.foreground
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 12
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
            font.family: Theme.bodyFontFamily
            font.pixelSize: 14
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
                color: root.eventsError.length > 0 ? Theme.red : Theme.muted
                font.family: Theme.bodyFontFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: root.eventsLoading ? [] : root.events

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.eventRowHeight
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
                            text: root.eventTime(modelData)
                            visible: text.length > 0
                            color: Theme.blue
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.eventTitle(modelData)
                            color: Theme.foreground
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                    }

                    MouseArea {
                        id: eventMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openEvent(root.eventTitle(modelData))
                    }

                }

            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.inputHeight
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
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 12
                    activeFocusOnPress: true
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    onActiveFocusChanged: {
                        if (activeFocus)
                            root.focusRequested();

                    }
                    onTextChanged: root.newEventTitle = text
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: eventInput.text.length === 0
                    text: "New event title"
                    color: Theme.muted
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 12
                }

            }

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: root.inputHeight
                radius: 5
                color: addMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                border.color: Theme.surfaceAlt
                border.width: 1
                opacity: addMouse.enabled ? 1 : 0.55

                Text {
                    anchors.centerIn: parent
                    text: root.addBusy ? "…" : "+"
                    color: Theme.green
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                }

                MouseArea {
                    id: addMouse

                    anchors.fill: parent
                    enabled: !root.addBusy && root.newEventTitle.trim().length > 0
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        root.addEvent(root.isoDate(root.selectedDate), root.newEventTitle.trim());
                    }
                }

            }

        }

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: root.addStatusHeight
            visible: root.addError.length > 0
            text: root.addError
            color: Theme.red
            font.family: Theme.bodyFontFamily
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

    }

}
