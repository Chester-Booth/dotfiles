import "../shared/Fuzzy.js" as Fuzzy
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string query: ""
    property var allItems: []
    property var items: []
    property int selectedIndex: 0
    property string category: "Search"
    property var toneMap: ({
    })
    readonly property bool copyBusy: copy.running
    readonly property var categories: ["Search", "Recent", "Smileys & Emotion", "People & Body", "Animals & Nature", "Food & Drink", "Activities", "Travel & Places", "Objects", "Flags", "Symbols"]
    readonly property var toneNames: ["", "light skin tone", "medium-light skin tone", "medium skin tone", "medium-dark skin tone", "dark skin tone"]

    signal closeRequested()
    signal pasteRequested()

    function itemKey(item) {
        return String(item.baseValue || item.value || "");
    }

    function filter() {
        const needle = root.category === "Search" ? query.trim() : "";
        const source = root.category === "Recent" && !needle.length ? LauncherState.recentEmoji : allItems;
        const matches = source.filter((item) => {
            return !/: .*skin tone$/.test(item.name) && (root.category === "Search" || root.category === "Recent" || item.category === root.category);
        }).map((item, order) => {
            const key = root.itemKey(item);
            const usage = LauncherState.emojiUsage[key] || ({
            });
            return {
                "item": item,
                "pinned": LauncherState.pinnedEmoji.indexOf(key) >= 0,
                "lastUsed": Number(usage.lastUsed || 0),
                "order": order,
                "score": needle.length ? Fuzzy.score(needle, item.name + " " + item.keywords) : 0
            };
        }).filter((candidate) => {
            return candidate.score >= 0;
        });
        matches.sort((a, b) => {
            if (a.pinned !== b.pinned)
                return a.pinned ? -1 : 1;

            if (needle.length && a.score !== b.score)
                return b.score - a.score;

            if (root.category === "Recent")
                return b.lastUsed - a.lastUsed;

            return a.order - b.order;
        });
        items = matches.map((candidate) => {
            const item = candidate.item;
            const toned = LauncherState.emojiTone > 0 ? root.toneMap[item.name + ": " + root.toneNames[LauncherState.emojiTone]] : "";
            return {
                "value": toned || item.value,
                "name": item.name,
                "keywords": item.keywords,
                "category": item.category,
                "baseValue": root.itemKey(item),
                "pinned": candidate.pinned
            };
        });
        selectedIndex = 0;
    }

    function activate() {
        if (copy.running || !items[selectedIndex])
            return ;

        copy.command = ["wl-copy", items[selectedIndex].value];
        copy.running = true;
        const used = items[selectedIndex];
        const recent = LauncherState.recentEmoji.filter((item) => {
            return root.itemKey(item) !== root.itemKey(used);
        });
        recent.unshift(used);
        LauncherState.recentEmoji = recent.slice(0, 50);
        const usage = Object.assign({
        }, LauncherState.emojiUsage);
        const key = root.itemKey(used);
        const previous = usage[key] || ({
        });
        usage[key] = {
            "count": Number(previous.count || 0) + 1,
            "lastUsed": Date.now()
        };
        LauncherState.emojiUsage = usage;
        root.filter();
    }

    function togglePin(index) {
        const item = items[index];
        if (!item)
            return ;

        const pins = LauncherState.pinnedEmoji.slice();
        const key = root.itemKey(item);
        const existing = pins.indexOf(key);
        if (existing >= 0)
            pins.splice(existing, 1);
        else
            pins.push(key);
        LauncherState.pinnedEmoji = pins;
        filter();
    }

    function migrateLegacyState() {
        const values = ({
        });
        const names = ({
        });
        for (const item of allItems) {
            values[item.value] = true;
            if (names[item.name] === undefined)
                names[item.name] = item.value;

        }
        let changed = false;
        const pins = LauncherState.pinnedEmoji.map((key) => {
            if (!values[key] && names[key] !== undefined) {
                changed = true;
                return names[key];
            }
            return key;
        });
        const usage = Object.assign({
        }, LauncherState.emojiUsage);
        for (const key of Object.keys(usage)) {
            if (!values[key] && names[key] !== undefined) {
                const target = names[key];
                const previous = usage[target] || ({
                    "count": 0,
                    "lastUsed": 0
                });
                usage[target] = {
                    "count": Number(previous.count || 0) + Number(usage[key].count || 0),
                    "lastUsed": Math.max(Number(previous.lastUsed || 0), Number(usage[key].lastUsed || 0))
                };
                delete usage[key];
                changed = true;
            }
        }
        const seenRecent = ({
        });
        const recent = [];
        for (const item of LauncherState.recentEmoji) {
            const hasTone = ["🏻", "🏼", "🏽", "🏾", "🏿"].some((tone) => {
                return String(item.value || "").indexOf(tone) >= 0;
            });
            const baseValue = item.baseValue || (hasTone ? names[item.name] : "") || (values[item.value] ? item.value : "") || names[item.name] || item.value;
            if (!baseValue || seenRecent[baseValue]) {
                changed = true;
                continue;
            }
            seenRecent[baseValue] = true;
            if (item.baseValue !== baseValue)
                changed = true;

            recent.push(Object.assign({
            }, item, {
                "baseValue": baseValue
            }));
        }
        if (changed) {
            LauncherState.pinnedEmoji = pins;
            LauncherState.emojiUsage = usage;
            LauncherState.recentEmoji = recent;
        }
    }

    onQueryChanged: filter()
    onCategoryChanged: {
        if (category !== "Search" && query.length)
            query = "";

        filter();
    }

    Connections {
        function onEmojiToneChanged() {
            root.filter();
        }

        target: LauncherState
    }

    FileView {
        path: Qt.resolvedUrl("../assets/emoji.json")
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                root.allItems = JSON.parse(text()).items || [];
                root.migrateLegacyState();
                const tones = {
                };
                for (const item of root.allItems) if (/: .*skin tone$/.test(item.name)) {
                    tones[item.name] = item.value;
                }
                root.toneMap = tones;
            } catch (error) {
                root.allItems = [];
            }
            root.filter();
        }
    }

    Process {
        id: copy

        onExited: (exitCode) => {
            if (exitCode === 0)
                root.pasteRequested();
            else
                Quickshell.execDetached(["notify-send", "--app-name", "Blox emoji picker", "--expire-time", "2500", "Emoji error", "The selected emoji could not be copied."]);
        }
    }

}
