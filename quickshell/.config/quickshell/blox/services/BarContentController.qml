import "."
import QtQuick
import Quickshell

Scope {
    id: root

    property string scriptRoot: ""
    property bool barVisible: true
    property string openPanel: ""
    property bool batteryExpanded: false
    property bool clockDateMode: false
    property string selectedCalendarDate: ""
    property alias status: barStatus
    property alias actions: barActions
    property alias content: barContent
    property alias workspaces: barStatus.workspaces
    property alias systemInfo: barStatus.system
    property alias todo: barStatus.todo
    property alias calendar: barStatus.calendar
    property alias updates: barStatus.updates
    property alias battery: barStatus.battery
    property alias audio: barStatus.audio
    property alias brightness: barStatus.brightness
    property alias network: barStatus.network
    property alias bluetooth: barStatus.bluetooth
    property alias touchpad: barStatus.touchpad
    property alias privacy: barStatus.privacy
    property alias caffeine: barStatus.caffeine
    readonly property date now: clock.date

    function run(command) {
        barActions.run(command);
    }

    function runArgs(args) {
        barActions.runArgs(args);
    }

    function runPerformance(command) {
        barActions.runPerformance(command);
    }

    function setPerformancePolling(visible) {
        barStatus.performanceVisible = visible;
    }

    function updateIcon() {
        return barContent.updateIcon();
    }

    function railClockText(horizontal) {
        return barContent.railClockText(horizontal);
    }

    function currentIsoDate() {
        return Qt.formatDate(clock.date, "yyyy-MM-dd");
    }

    function resetCalendarMonth() {
        selectedCalendarDate = currentIsoDate();
        barStatus.calendar.refresh();
    }

    function selectCalendarDate(day) {
        selectedCalendarDate = day;
        barStatus.calendar.refresh();
    }

    function openCalendar() {
        const date = selectedCalendarDate ? new Date(selectedCalendarDate + "T00:00:00") : clock.date;
        run("xdg-open 'https://calendar.google.com/calendar/u/0/r/week/" + date.getFullYear() + "/" + (date.getMonth() + 1) + "/" + date.getDate() + "'");
    }

    function previousTodo() {
        run(scriptRoot + "/todo/cycle.sh -1");
        todoRefreshDelay.restart();
    }

    function nextTodo() {
        run(scriptRoot + "/todo/cycle.sh 1");
        todoRefreshDelay.restart();
    }

    function statusError(panel) {
        const pollers = {
            "audio": audio,
            "network": network,
            "bluetooth": bluetooth,
            "brightness": brightness,
            "privacy": privacy,
            "caffeine": caffeine,
            "updates": updates,
            "todo": todo,
            "system": systemInfo
        };
        const poller = pollers[panel];
        return poller && !poller.ok ? poller.lastError : "";
    }

    BarStatus {
        id: barStatus

        scriptRoot: root.scriptRoot
        barVisible: root.barVisible
        openPanel: root.openPanel
        selectedCalendarDate: root.selectedCalendarDate
        todayIso: root.currentIsoDate()
    }

    BarActions {
        id: barActions

        scriptRoot: root.scriptRoot
        onControlRefreshRequested: barStatus.refreshControl()
        onPerformanceRefreshRequested: barStatus.refreshPerformance()
        onTodoRefreshRequested: todoRefreshDelay.restart()
        onCalendarRefreshRequested: barStatus.calendar.refresh()
    }

    BarContent {
        id: barContent

        openPanel: root.openPanel
        scriptRoot: root.scriptRoot
        now: clock.date
        clockDateMode: root.clockDateMode
        updates: root.updates.json
        updatesLastUpdatedMs: root.updates.lastUpdatedMs
        bluetooth: root.bluetooth.json
        audio: root.audio.json
        brightness: root.brightness.json
        network: root.network.json
        privacy: root.privacy.json
        caffeine: root.caffeine.json
    }

    Timer {
        id: todoRefreshDelay

        interval: 120
        repeat: false
        onTriggered: barStatus.todo.refresh()
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

}
