import "../shared"
import QtQuick

Item {
    id: root

    required property BarPopoutGeometry geometry
    property string openPanel: ""
    property var todoStatus
    property int saveRevision: 0
    property bool saveBusy: false
    property string saveError: ""
    property string statusError: ""
    property bool refreshBusy: false
    property string refreshError: ""

    signal hoverEntered()
    signal hoverExited()
    signal inputLockChanged(bool locked)
    signal previous()
    signal next()
    signal refresh(string file)
    signal save(string file, string body)

    HoverPopupWindow {
        id: notesWindow

        anchorWindow: root.geometry.panelWindow
        anchorX: root.geometry.popupX(notesPopout.width, root.geometry.openPanelX)
        anchorY: root.geometry.popupY(notesPopout.height, root.geometry.openPanelY)
        contentWidth: notesPopout.width
        contentHeight: notesPopout.height
        persistentKeyboardFocus: notesPopout.editing
        open: root.openPanel === "todo"
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onVisibleChanged: {
            if (!visible)
                root.inputLockChanged(false);

        }

        NotesPopout {
            id: notesPopout

            headerActionsOnRight: Theme.barPosition === "right" || ((Theme.barPosition === "top" || Theme.barPosition === "bottom") && root.geometry.openPanelX > root.geometry.screenWidth / 2)
            title: root.todoStatus && root.todoStatus.name ? root.todoStatus.name : "notes.md"
            body: root.todoStatus && root.todoStatus.raw ? root.todoStatus.raw : ""
            file: root.todoStatus && root.todoStatus.file ? root.todoStatus.file : ""
            index: root.todoStatus && root.todoStatus.index !== undefined ? root.todoStatus.index : 0
            count: root.todoStatus && root.todoStatus.count !== undefined ? root.todoStatus.count : 1
            saveRevision: root.saveRevision
            saveBusy: root.saveBusy
            saveError: root.saveError
            statusError: root.statusError
            refreshBusy: root.refreshBusy
            refreshError: root.refreshError
            maxPopoutWidth: root.geometry.screenWidth > 0 ? root.geometry.screenWidth * 0.75 : 680
            maxPopoutHeight: root.geometry.screenHeight > 0 ? root.geometry.screenHeight * 0.75 : 760
            onPrevious: root.previous()
            onNext: root.next()
            onRefresh: (file) => {
                return root.refresh(file);
            }
            onSave: (file, body) => {
                return root.save(file, body);
            }
            onEditingChanged: root.inputLockChanged(editing)
            onFocusRequested: {
                root.inputLockChanged(true);
                notesWindow.requestKeyboardFocus();
            }
        }

    }

}
