import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    required property string scriptRoot
    readonly property int refreshTimeoutMs: 20000
    property var events: []
    property var calendars: []
    property bool loading: false
    property bool refreshing: false
    property string error: ""
    property int revision: 0
    property var activeScreen: null
    property bool detailsOpen: false
    property bool editorOpen: false
    property bool confirmDeleteOpen: false
    property bool eventMenuOpen: false
    property bool childPositionReady: false
    property string deleteScope: "instance"
    property var activeEvent: null
    property date selectedDate: new Date()
    property date rangeDate: selectedDate
    readonly property bool childWindowOpen: detailsOpen || editorOpen || confirmDeleteOpen || eventMenuOpen
    property string pendingCommand: ""
    property var pendingPayload: null
    property var rollbackEvents: null
    property var coverage: []
    property bool coverageComplete: false
    property double coverageOldestMs: 0
    property var commandQueue: []
    property var activeCommand: null
    property var refreshedAt: ({
    })
    property double lastHoverRefreshMs: 0

    function defaultCalendar() {
        var writable = calendars.filter(function(c) {
            return c.write_allowed;
        });
        return writable.filter(function(c) {
            return c.primary;
        })[0] || writable[0] || null;
    }

    function iso(date) {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    function retainedRange(date) {
        return {
            "start": new Date(date.getFullYear(), date.getMonth() - 1, 1).toISOString(),
            "end": new Date(date.getFullYear(), date.getMonth() + 2, 1).toISOString()
        };
    }

    function startOfDay(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate());
    }

    function endOfDay(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1);
    }

    function monthRange(date) {
        return {
            "start": new Date(date.getFullYear(), date.getMonth(), 1),
            "end": new Date(date.getFullYear(), date.getMonth() + 1, 1)
        };
    }

    function rangeKey(start, end) {
        return start.toISOString() + "/" + end.toISOString();
    }

    function open(date, screen) {
        selectedDate = date;
        activeScreen = screen;
        snapshot();
    }

    function snapshot(date) {
        if (snapshotProcess.running)
            return ;

        rangeDate = date || selectedDate;
        var range = retainedRange(rangeDate);
        loading = events.length === 0;
        error = "";
        snapshotProcess.command = [root.scriptRoot + "/calendar/calendar_adapter.py", "snapshot", "--start", range.start, "--end", range.end];
        snapshotProcess.running = true;
    }

    function requestRefresh(start, end, reason, maxAgeMs, priority) {
        if (!(start instanceof Date))
            start = new Date(start);

        if (!(end instanceof Date))
            end = new Date(end);

        if (end <= start)
            return false;

        var key = rangeKey(start, end), now = Date.now(), age = maxAgeMs === undefined ? 0 : maxAgeMs;
        if (age > 0 && refreshedAt[key] && now - refreshedAt[key] < age)
            return false;

        if (activeCommand && activeCommand.command === "refresh" && activeCommand.key === key)
            return false;

        if (commandQueue.some(function(item) {
            return item.command === "refresh" && item.key === key;
        }))
            return false;

        enqueue({
            "command": "refresh",
            "payload": null,
            "args": ["--start", start.toISOString(), "--end", end.toISOString()],
            "key": key,
            "reason": reason || "manual",
            "rollback": null
        }, priority === true);
        return true;
    }

    function refresh(force) {
        var range = retainedRange(rangeDate);
        return requestRefresh(new Date(range.start), new Date(range.end), "manual", force ? 0 : 3.6e+06, false);
    }

    function refreshOnHover() {
        var now = Date.now();
        if (now - lastHoverRefreshMs < 30000)
            return ;

        lastHoverRefreshMs = now;
        var today = new Date(), month = monthRange(today);
        requestRefresh(startOfDay(today), endOfDay(today), "hover", 30000, false);
        requestRefresh(month.start, month.end, "hover", 30000, false);
    }

    function refreshHourlyRanges() {
        var now = new Date(), tomorrow = endOfDay(now), weekEnd = new Date(tomorrow);
        weekEnd.setDate(weekEnd.getDate() + ((7 - weekEnd.getDay()) % 7));
        if (weekEnd > tomorrow)
            requestRefresh(tomorrow, weekEnd, "hourly", 3.6e+06, false);

        var next = monthRange(new Date(now.getFullYear(), now.getMonth() + 1, 1));
        requestRefresh(next.start, next.end, "hourly", 3.6e+06, false);
    }

    function refreshDailyRanges() {
        var now = new Date(), monday = startOfDay(now);
        monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
        var nextWeek = new Date(monday);
        nextWeek.setDate(nextWeek.getDate() + 7);
        var twoWeeks = new Date(monday);
        twoWeeks.setDate(twoWeeks.getDate() + 14);
        requestRefresh(nextWeek, twoWeeks, "daily", 8.64e+07, false);
        var later = new Date(now.getFullYear(), now.getMonth() + 2, 1), yearEnd = new Date(now.getFullYear() + 1, 0, 1);
        if (later < yearEnd)
            requestRefresh(later, yearEnd, "daily", 8.64e+07, false);

    }

    function refreshViewedDate(date, viewKind) {
        var range = viewKind === "month" ? monthRange(date) : {
            "start": startOfDay(date),
            "end": endOfDay(date)
        };
        requestRefresh(range.start, range.end, "navigation", 300000, false);
    }

    function finishNavigation(date, viewKind) {
        refreshViewedDate(date, viewKind);
    }

    function refreshAfterMutation(eventOrDate) {
        var date = eventOrDate instanceof Date ? eventOrDate : eventOrDate && eventOrDate.time && eventOrDate.time.kind === "timed" ? new Date(eventOrDate.time.start_ms) : selectedDate;
        requestRefresh(startOfDay(date), endOfDay(date), "mutation", 0, true);
        var month = monthRange(date);
        requestRefresh(month.start, month.end, "mutation", 0, true);
    }

    function showDetails(event) {
        childPositionReady = false;
        activeEvent = event;
        detailsOpen = true;
        editorOpen = false;
    }

    function editEvent(event) {
        childPositionReady = false;
        activeEvent = event;
        detailsOpen = false;
        editorOpen = true;
    }

    function createEvent(date, startHour, endHour) {
        var calendar = defaultCalendar();
        if (!calendar) {
            error = "No writable calendar is allowed.";
            return false;
        }
        activeEvent = {
            "key": "local:draft",
            "id": "",
            "etag": "",
            "title": "",
            "description": "",
            "location": "",
            "event_type": "default",
            "locked": false,
            "calendar": calendar,
            "colour": {
                "event_id": "",
                "display": calendar.colour,
                "calendar_fallback": calendar.colour
            },
            "recurrence": {
                "master_id": "",
                "summary": "",
                "custom": false
            },
            "time": {
                "kind": "timed",
                "start_ms": dayTime(date, startHour).getTime(),
                "end_ms": dayTime(date, endHour).getTime(),
                "start_zone": calendar.time_zone || "",
                "end_zone": calendar.time_zone || ""
            },
            "can_edit": true,
            "capability_reason": "",
            "cache": {
                "stale": false,
                "operation": "draft"
            }
        };
        childPositionReady = false;
        detailsOpen = false;
        editorOpen = true;
        return true;
    }

    function closeChildren() {
        detailsOpen = false;
        editorOpen = false;
        confirmDeleteOpen = false;
        eventMenuOpen = false;
        activeEvent = null;
    }

    function write(command, payload, optimisticEvents, refreshDate) {
        error = "";
        pendingCommand = command;
        pendingPayload = payload;
        var rollback = events;
        if (optimisticEvents !== undefined)
            events = optimisticEvents;

        enqueue({
            "command": command,
            "payload": payload,
            "args": [],
            "rollback": rollback,
            "refreshDate": refreshDate || null
        }, true);
        return true;
    }

    function enqueue(item, priority) {
        var next = commandQueue.slice();
        if (priority)
            next.unshift(item);
        else
            next.push(item);
        commandQueue = next;
        startNext();
        updateRefreshing();
    }

    function updateRefreshing() {
        refreshing = mutator.running || commandQueue.length > 0 || activeCommand !== null;
    }

    function startNext() {
        if (mutator.running || !commandQueue.length)
            return ;

        var next = commandQueue[0];
        commandQueue = commandQueue.slice(1);
        activeCommand = next;
        pendingCommand = next.command;
        pendingPayload = next.payload;
        rollbackEvents = next.rollback || null;
        mutator.command = [root.scriptRoot + "/calendar/calendar_adapter.py", next.command].concat(next.args);
        mutator.running = true;
        processTimeout.restart();
        updateRefreshing();
    }

    function saveEvent(title, description, location, chosenDate, chosenStart, chosenEnd, colourId, allDay, calendarId, recurrenceRule) {
        if (!title.trim()) {
            error = "Add an event title.";
            return false;
        }
        var item = activeEvent, calendar = calendars.filter(function(c) {
            return c.id === calendarId;
        })[0] || item.calendar || defaultCalendar();
        if (!calendar) {
            error = "No writable calendar is allowed.";
            return false;
        }
        var sourceStart = chosenStart || new Date(item.time.start_ms), sourceEnd = chosenEnd || new Date(item.time.end_ms), date = chosenDate || sourceStart;
        var start = new Date(date.getFullYear(), date.getMonth(), date.getDate(), sourceStart.getHours(), sourceStart.getMinutes());
        var end = new Date(date.getFullYear(), date.getMonth(), date.getDate(), sourceEnd.getHours(), sourceEnd.getMinutes());
        if (end <= start)
            end.setDate(end.getDate() + 1);

        var changes = {
            "summary": title.trim(),
            "description": description,
            "location": location
        };
        if (allDay) {
            changes.start = {
                "date": iso(date)
            };
            var next = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1);
            changes.end = {
                "date": iso(next)
            };
        } else {
            changes.start = {
                "dateTime": start.toISOString()
            };
            changes.end = {
                "dateTime": end.toISOString()
            };
            if (item.time.start_zone)
                changes.start.timeZone = item.time.start_zone;

            if (item.time.end_zone)
                changes.end.timeZone = item.time.end_zone;
        }
        if (colourId !== undefined)
            changes.colorId = colourId || null;

        if (recurrenceRule)
            changes.recurrence = [recurrenceRule];
        else if (recurrenceRule === "")
            changes.recurrence = [];
        var queued = false;
        if (item.id) {
            if (calendar.id !== item.calendar.id)
                queued = write("move", {
                "calendar_id": item.calendar.id,
                "destination_id": calendar.id,
                "event_id": item.id,
                "etag": item.etag,
                "changes": changes
            }, undefined, start);
            else
                queued = write("update", {
                "calendar_id": calendar.id,
                "event_id": item.id,
                "etag": item.etag,
                "changes": changes
            }, undefined, start);
        } else {
            queued = write("create", {
                "calendar_id": calendar.id,
                "event": changes
            }, undefined, start);
        }
        if (queued)
            closeChildren();

        return queued;
    }

    function requestDelete(event, openHost) {
        if (event && event.can_edit) {
            activeEvent = event;
            deleteScope = "instance";
            if (openHost !== false && !detailsOpen && !editorOpen) {
                childPositionReady = false;
                detailsOpen = true;
            }
            confirmDeleteOpen = true;
        }
    }

    function cancelDelete() {
        confirmDeleteOpen = false;
    }

    function confirmDelete() {
        var event = activeEvent;
        if (event && event.can_edit) {
            if (write("delete", {
                "calendar_id": event.calendar.id,
                "event_id": event.id,
                "etag": event.etag,
                "scope": deleteScope,
                "master_id": event.recurrence ? event.recurrence.master_id : "",
                "original_start": event.recurrence ? event.recurrence.original_start : null
            }))
                closeChildren();

        }
    }

    function dayTime(date, hour) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate(), Math.floor(hour), Math.round((hour % 1) * 60));
    }

    function moveEventTime(event, date, startHour) {
        if (!event.can_edit || event.time.kind !== "timed")
            return ;

        var duration = event.time.end_ms - event.time.start_ms, start = dayTime(date, startHour);
        var candidate = Object.assign({
        }, event), time = Object.assign({
        }, event.time);
        time.start_ms = start.getTime();
        time.end_ms = start.getTime() + duration;
        candidate.time = time;
        candidate.pending = true;
        write("update", {
            "calendar_id": event.calendar.id,
            "event_id": event.id,
            "etag": event.etag,
            "changes": {
                "start": {
                    "dateTime": start.toISOString(),
                    "timeZone": event.time.start_zone
                },
                "end": {
                    "dateTime": new Date(start.getTime() + duration).toISOString(),
                    "timeZone": event.time.end_zone
                }
            }
        }, events.map(function(item) {
            return item.key === event.key ? candidate : item;
        }));
    }

    function resizeEventTime(event, date, endHour) {
        if (!event.can_edit || event.time.kind !== "timed")
            return ;

        var end = dayTime(date, endHour);
        var candidate = Object.assign({
        }, event), time = Object.assign({
        }, event.time);
        time.end_ms = end.getTime();
        candidate.time = time;
        candidate.pending = true;
        write("update", {
            "calendar_id": event.calendar.id,
            "event_id": event.id,
            "etag": event.etag,
            "changes": {
                "end": {
                    "dateTime": end.toISOString(),
                    "timeZone": event.time.end_zone
                }
            }
        }, events.map(function(item) {
            return item.key === event.key ? candidate : item;
        }));
    }

    function changeEventColour(event, colourId) {
        if (!event || !event.can_edit)
            return false;

        var palette = {
            "9": "#5484ed",
            "3": "#dbadff",
            "7": "#46d6db",
            "5": "#fbd75b",
            "11": "#dc2127",
            "1": "#a4bdfc",
            "10": "#51b749",
            "2": "#7ae7bf",
            "6": "#ffb878",
            "4": "#ff887c"
        };
        var candidate = Object.assign({
        }, event), colour = Object.assign({
        }, event.colour);
        colour.event_id = colourId;
        colour.display = palette[colourId] || colour.display;
        candidate.colour = colour;
        candidate.pending = true;
        return write("update", {
            "calendar_id": event.calendar.id,
            "event_id": event.id,
            "etag": event.etag,
            "changes": {
                "colorId": colourId
            }
        }, events.map(function(item) {
            return item.key === event.key ? candidate : item;
        }));
    }

    function acceptOutput(text) {
        try {
            var response = JSON.parse(text);
            if (!response.ok) {
                error = response.error.message;
                return ;
            }
            revision = response.revision;
            if (response.data.events && modelSignature(events) !== modelSignature(response.data.events))
                events = response.data.events;

            if (response.data.calendars && JSON.stringify(calendars) !== JSON.stringify(response.data.calendars))
                calendars = response.data.calendars;

            if (response.data.coverage)
                coverage = response.data.coverage;

            if (response.data.coverage_complete !== undefined)
                coverageComplete = response.data.coverage_complete;

            if (response.data.coverage_oldest_ms !== undefined)
                coverageOldestMs = response.data.coverage_oldest_ms;

            if (response.data.range_freshness) {
                var fresh = Object.assign({
                }, refreshedAt);
                for (var i = 0; i < response.data.range_freshness.length; ++i) {
                    var item = response.data.range_freshness[i];
                    fresh[rangeKey(new Date(item.start_utc), new Date(item.end_utc))] = item.refreshed_at_ms;
                }
                refreshedAt = fresh;
            }
        } catch (e) {
            error = "Calendar returned invalid data: " + e;
        }
    }

    function modelSignature(model) {
        return JSON.stringify(model.map(function(e) {
            return {
                "key": e.key,
                "etag": e.etag,
                "title": e.title,
                "description": e.description,
                "location": e.location,
                "time": e.time,
                "colour": e.colour,
                "calendar": e.calendar,
                "recurrence": e.recurrence,
                "can_edit": e.can_edit,
                "pending": e.pending || false
            };
        }));
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshHourlyRanges()
    }

    Timer {
        interval: 60 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshDailyRanges()
    }

    Timer {
        id: processTimeout

        interval: root.refreshTimeoutMs
        onTriggered: {
            if (mutator.running) {
                root.error = "Calendar refresh timed out.";
                mutator.running = false;
                root.rollbackEvents = null;
                root.activeCommand = null;
                root.pendingPayload = null;
                root.startNext();
                root.updateRefreshing();
            }
        }
    }

    Process {
        id: snapshotProcess

        onExited: function(code) {
            root.loading = false;
            if (code === 0)
                root.acceptOutput(snapshotOutput.text);
            else
                root.error = "Could not read the calendar cache.";
        }

        stdout: StdioCollector {
            id: snapshotOutput
        }

        stderr: StdioCollector {
            id: snapshotErrors
        }

    }

    Process {
        id: mutator

        stdinEnabled: true
        onStarted: {
            if (root.pendingPayload)
                write(JSON.stringify(root.pendingPayload) + "\n");

        }
        onExited: function(code) {
            processTimeout.stop();
            var finished = root.activeCommand;
            root.activeCommand = null;
            root.pendingPayload = null;
            if (code === 0) {
                root.rollbackEvents = null;
                root.acceptOutput(mutatorOutput.text);
                if (finished && finished.command === "refresh") {
                    var next = Object.assign({
                    }, root.refreshedAt);
                    next[finished.key] = Date.now();
                    root.refreshedAt = next;
                } else if (finished) {
                    root.refreshAfterMutation(finished.refreshDate || root.activeEvent);
                }
            } else {
                if (root.rollbackEvents)
                    root.events = root.rollbackEvents;

                root.rollbackEvents = null;
                root.acceptOutput(mutatorOutput.text);
            }
            root.startNext();
            root.updateRefreshing();
        }

        stdout: StdioCollector {
            id: mutatorOutput
        }

        stderr: StdioCollector {
            id: mutatorErrors
        }

    }

}
