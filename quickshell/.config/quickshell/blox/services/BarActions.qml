import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string scriptRoot: ""
    property int notesSaveRevision: 0
    property bool notesSaveBusy: false
    property string notesSaveError: ""
    property bool generatedRefreshBusy: false
    property string generatedRefreshError: ""
    property int calendarAddRevision: 0
    property bool calendarAddBusy: false
    property string calendarAddError: ""
    property bool performanceBusy: false
    property string performanceError: ""
    property string performanceProcessError: ""
    property string notesProcessError: ""
    property string generatedProcessError: ""
    property string calendarProcessError: ""

    signal controlRefreshRequested()
    signal performanceRefreshRequested()
    signal todoRefreshRequested()
    signal calendarRefreshRequested()

    function errorMessage(prefix, exitCode, errorOutput) {
        const lines = errorOutput.trim().split("\n").filter((line) => {
            return line.trim().length > 0;
        });
        const detail = lines.length > 0 ? lines[lines.length - 1].trim().slice(0, 180) : "";
        return detail.length > 0 ? prefix + ": " + detail : prefix + " (exit " + exitCode + ")";
    }

    function run(command) {
        if (command.length === 0)
            return ;

        Quickshell.execDetached(["sh", "-c", command]);
        refreshDelay.restart();
    }

    function runArgs(args) {
        if (args.length === 0)
            return ;

        Quickshell.execDetached(args);
        refreshDelay.restart();
    }

    function runPerformance(command) {
        if (command.length === 0 || performanceProcess.running)
            return ;

        performanceProcessError = "";
        performanceError = "";
        performanceBusy = true;
        performanceProcess.command = ["timeout", "45s", "sh", "-c", command];
        performanceProcess.running = true;
    }

    function saveNotes(file, body) {
        if (notesProcess.running) {
            notesSaveError = "A note is already being saved.";
            return ;
        }
        if (file.length === 0) {
            notesSaveError = "No note file is selected.";
            return ;
        }
        notesProcessError = "";
        notesSaveError = "";
        notesSaveBusy = true;
        notesProcess.command = [scriptRoot + "/todo/save.py", file, body];
        notesProcess.running = true;
    }

    function refreshGeneratedNotes() {
        if (generatedProcess.running) {
            generatedRefreshError = "Generated notes are already being refreshed.";
            return ;
        }
        generatedProcessError = "";
        generatedRefreshError = "";
        generatedRefreshBusy = true;
        generatedProcess.command = ["timeout", "90s", scriptRoot + "/todo/generated-refresh.sh"];
        generatedProcess.running = true;
    }

    function addCalendarEvent(day, title) {
        if (calendarProcess.running) {
            calendarAddError = "An event is already being added.";
            return ;
        }
        calendarProcessError = "";
        calendarAddError = "";
        calendarAddBusy = true;
        calendarProcess.command = [scriptRoot + "/calendar/add-event.sh", day, title];
        calendarProcess.running = true;
    }

    Timer {
        id: refreshDelay

        interval: 500
        repeat: false
        onTriggered: {
            root.controlRefreshRequested();
            root.performanceRefreshRequested();
        }
    }

    Process {
        id: performanceProcess

        onExited: (exitCode, exitStatus) => {
            root.performanceBusy = false;
            if (exitCode !== 0 || exitStatus !== 0)
                root.performanceError = root.errorMessage("Performance action failed", exitCode, root.performanceProcessError);

            root.controlRefreshRequested();
            root.performanceRefreshRequested();
        }

        stderr: StdioCollector {
            onStreamFinished: root.performanceProcessError = this.text
        }

    }

    Process {
        id: notesProcess

        onExited: (exitCode, exitStatus) => {
            root.notesSaveBusy = false;
            if (exitCode === 0 && exitStatus === 0) {
                root.notesSaveRevision += 1;
                root.notesSaveError = "";
            } else {
                root.notesSaveError = root.errorMessage("Could not save the note", exitCode, root.notesProcessError);
            }
            root.todoRefreshRequested();
        }

        stderr: StdioCollector {
            onStreamFinished: root.notesProcessError = this.text
        }

    }

    Process {
        id: generatedProcess

        onExited: (exitCode, exitStatus) => {
            root.generatedRefreshBusy = false;
            if (exitCode === 0 && exitStatus === 0)
                root.generatedRefreshError = "";
            else if (exitCode === 75)
                root.generatedRefreshError = "Generated notes are already being refreshed.";
            else
                root.generatedRefreshError = root.errorMessage("Could not refresh generated notes", exitCode, root.generatedProcessError);
            root.todoRefreshRequested();
        }

        stderr: StdioCollector {
            onStreamFinished: root.generatedProcessError = this.text
        }

    }

    Process {
        id: calendarProcess

        onExited: (exitCode, exitStatus) => {
            root.calendarAddBusy = false;
            if (exitCode === 0 && exitStatus === 0) {
                root.calendarAddRevision += 1;
                root.calendarAddError = "";
                root.calendarRefreshRequested();
            } else {
                root.calendarAddError = root.errorMessage("Could not add the event", exitCode, root.calendarProcessError);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: root.calendarProcessError = this.text
        }

    }

}
