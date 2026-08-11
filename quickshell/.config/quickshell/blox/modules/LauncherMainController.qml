import "../shared/Fuzzy.js" as Fuzzy
import "../shared/LauncherLogic.js" as LauncherLogic
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string query: ""
    property int selectedIndex: 0
    property int requestSerial: 0
    property int pendingQalcSerial: 0
    property string pendingQalcQuery: ""
    property var results: []
    property string calculation: ""
    property bool calculationSelected: false
    property bool dmenuMode: false
    property string dmenuPrompt: ""
    property var dmenuOptions: []
    property bool dmenuInsensitive: false
    property int dmenuLimit: 0
    property bool dmenuBottom: false
    property var pendingEntry: null
    readonly property var applicationCategories: [{
        "title": "Audio & Video",
        "key": "AudioVideo",
        "icon": "film-strip"
    }, {
        "title": "Development",
        "key": "Development",
        "icon": "code"
    }, {
        "title": "Education",
        "key": "Education",
        "icon": "graduation-cap"
    }, {
        "title": "Games",
        "key": "Game",
        "icon": "game-controller"
    }, {
        "title": "Graphics",
        "key": "Graphics",
        "icon": "palette"
    }, {
        "title": "Network",
        "key": "Network",
        "icon": "globe-hemisphere-west"
    }, {
        "title": "Office",
        "key": "Office",
        "icon": "briefcase"
    }, {
        "title": "Science",
        "key": "Science",
        "icon": "flask"
    }, {
        "title": "Settings",
        "key": "Settings",
        "icon": "gear-six"
    }, {
        "title": "System",
        "key": "System",
        "icon": "terminal-window"
    }, {
        "title": "Utilities",
        "key": "Utility",
        "icon": "wrench"
    }]

    signal closeRequested()
    signal dmenuSelected(string value)

    function normaliseId(value) {
        return LauncherLogic.normaliseId(value);
    }

    function looksLikeCalculation(value) {
        return LauncherLogic.looksLikeCalculation(value);
    }

    function qalcQuery(value) {
        return LauncherLogic.qalcQuery(value);
    }

    function categoryResults(applications) {
        return applicationCategories.map((category) => {
            const count = applications.filter((entry) => {
                return (entry.categories || []).some((value) => {
                    return String(value).toLowerCase() === category.key.toLowerCase();
                });
            }).length;
            return {
                "kind": "category",
                "title": category.title,
                "subtitle": count + (count === 1 ? " application" : " applications"),
                "iconName": category.icon,
                "categoryKey": category.key,
                "score": 0
            };
        });
    }

    function usageBoost(entry) {
        const key = normaliseId(entry.id || entry.name);
        const usage = LauncherState.applicationUsage[key] || ({
        });
        const countBoost = Math.min(15, Math.log2(Number(usage.count || 0) + 1) * 4);
        const age = Date.now() - Number(usage.lastUsed || 0);
        const recencyBoost = age >= 0 && age < 7 * 8.64e+07 ? 10 * (1 - age / (7 * 8.64e+07)) : 0;
        return countBoost + recencyBoost;
    }

    function recordUse(entry) {
        const key = normaliseId(entry.id || entry.name);
        const usage = Object.assign({
        }, LauncherState.applicationUsage);
        const previous = usage[key] || ({
        });
        usage[key] = {
            "count": Number(previous.count || 0) + 1,
            "lastUsed": Date.now()
        };
        LauncherState.applicationUsage = usage;
    }

    function iconSource(entry) {
        const icon = String(entry.icon || "");
        if (!icon.length)
            return "";
        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, true);
    }

    function executeCurrentDesktopEntry(entry) {
        const desktopId = String(entry.id || "").replace(/\.desktop$/, "");
        if (desktopId.length) {
            // DesktopEntries can retain an old Exec value after its source
            // file changes. Resolve the desktop file again at activation time,
            // so launcher clicks always use its current Exec.
            desktopLauncher.command = [Quickshell.env("HOME") + "/.config/quickshell/blox/scripts/launcher/desktop_exec.py", desktopId];
            desktopLauncher.running = true;
        } else {
            entry.execute();
        }
    }

    function refresh() {
        const text = query.trim();
        requestSerial++;
        pendingQalcSerial = 0;
        pendingQalcQuery = "";
        qalcDebounce.stop();
        if (qalc.running)
            qalc.signal(15);

        selectedIndex = 0;
        calculation = "";
        calculationSelected = false;
        if (!query.length && !dmenuMode) {
            results = [];
            return ;
        }
        if (dmenuMode) {
            const matched = dmenuOptions.map((option) => {
                return {
                    "kind": "dmenu",
                    "title": option,
                    "subtitle": "",
                    "icon": "",
                    "score": text.length ? Fuzzy.score(text, option, dmenuInsensitive) : 0
                };
            }).filter((result) => {
                return result.score >= 0;
            });
            matched.sort((left, right) => {
                return right.score - left.score;
            });
            results = matched.slice(0, 100);
            return ;
        }
        const applications = DesktopEntries.applications.values || [];
        if (query === "$") {
            results = categoryResults(applications);
            return ;
        }
        const categoryMatch = query.match(/^\$([^\s]+)$/);
        const categoryKey = categoryMatch ? categoryMatch[1].toLowerCase() : "";
        const scored = [];
        for (const entry of applications) {
            if (categoryKey && !(entry.categories || []).some((category) => {
                return String(category).toLowerCase() === categoryKey;
            }))
                continue;

            const tokens = [entry.name, entry.genericName, entry.comment, entry.keywords, entry.id].join(" ");
            const value = categoryKey ? 0 : text.length ? Fuzzy.score(text, tokens) : 0;
            if (value >= 0)
                scored.push({
                "kind": entry.runInTerminal ? "command" : "app",
                "title": entry.name,
                "subtitle": entry.comment || entry.id,
                "icon": iconSource(entry),
                "score": value + (text.length ? usageBoost(entry) : 0),
                "entry": entry
            });

        }
        scored.sort((left, right) => {
            return text.length ? right.score - left.score : left.title.localeCompare(right.title);
        });
        results = text.length ? scored : categoryResults(applications).concat(scored);
        if (looksLikeCalculation(text))
            qalcDebounce.restart();

    }

    function move(delta) {
        if (calculation.length) {
            if (calculationSelected) {
                if (results.length) {
                    calculationSelected = false;
                    selectedIndex = delta < 0 ? results.length - 1 : 0;
                }
                return ;
            }
            const next = selectedIndex + delta;
            if (next < 0 || next >= results.length) {
                calculationSelected = true;
                return ;
            }
            selectedIndex = next;
            return ;
        }
        if (results.length)
            selectedIndex = (selectedIndex + delta + results.length) % results.length;

    }

    function activateCalculation() {
        if (!calculation.length)
            return ;

        copyResult.command = ["wl-copy", calculation];
        copyResult.running = true;
        closeRequested();
    }

    function activateResult(index) {
        calculationSelected = false;
        const result = results[index === undefined ? selectedIndex : index];
        if (!result)
            return ;

        if (result.kind === "category") {
            query = "$" + result.categoryKey;
            return ;
        }
        if (result.kind === "command") {
            recordUse(result.entry);
            const command = ["kitty", "--detach"];
            if (result.entry.workingDirectory)
                command.push("--directory", result.entry.workingDirectory);

            for (const part of result.entry.command) command.push(part)
            terminalCommand.command = command;
            terminalCommand.running = true;
        } else if (result.kind === "app") {
            recordUse(result.entry);
            pendingEntry = result.entry;
            focusApp.command = [Quickshell.env("HOME") + "/.config/quickshell/blox/scripts/launcher/appctl.py", result.entry.id || "", result.entry.startupClass || ""];
            focusApp.running = true;
        } else {
            dmenuSelected(result.title);
        }
        closeRequested();
    }

    function activate() {
        if (calculation.length && calculationSelected)
            activateCalculation();
        else
            activateResult(selectedIndex);
    }

    function startPendingQalc() {
        if (qalc.running || pendingQalcSerial !== requestSerial || !pendingQalcQuery.length)
            return ;

        qalc.serial = pendingQalcSerial;
        qalc.command = ["qalc", "-t", "-m", "1200", pendingQalcQuery];
        pendingQalcSerial = 0;
        pendingQalcQuery = "";
        qalc.running = true;
    }

    onQueryChanged: refresh()

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.refresh();
        }
    }

    Timer {
        id: qalcDebounce

        interval: 175
        repeat: false
        onTriggered: {
            root.pendingQalcSerial = root.requestSerial;
            root.pendingQalcQuery = root.qalcQuery(root.query);
            if (qalc.running)
                qalc.signal(15);
            else
                root.startPendingQalc();
        }
    }

    Process {
        id: qalc

        property int serial: 0
        property string output: ""

        onRunningChanged: {
            if (running)
                output = "";

        }
        onExited: (exitCode) => {
            if (exitCode === 0 && qalc.serial === root.requestSerial && qalc.output.length) {
                root.calculation = qalc.output;
                root.calculationSelected = true;
            }
            if (root.pendingQalcSerial === root.requestSerial)
                Qt.callLater(root.startPendingQalc);

        }

        stdout: StdioCollector {
            onStreamFinished: {
                qalc.output = text.trim();
            }
        }

    }

    Process {
        id: copyResult
    }

    Process {
        id: focusApp

        onExited: (exitCode) => {
            if (exitCode === 3 && root.pendingEntry)
                root.executeCurrentDesktopEntry(root.pendingEntry);

            root.pendingEntry = null;
        }
    }

    Process {
        id: terminalCommand
    }

    Process {
        id: desktopLauncher
    }

}
