import QtQuick
import org.kde.taskmanager as TaskManager

// Keeps a list of the geometry of all visible windows on the current
// virtual desktop. A floating Plasma panel docks itself to the screen edge
// as soon as a window touches it, and the visualizer needs to know about
// that to stay glued to the panel. Created at runtime by main.qml, which
// copes with this file failing to load.
Item {
    id: watcher

    // [{ x, y, width, height }, ...] in global screen coordinates
    property var rects: []

    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasks
        virtualDesktop: virtualDesktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        filterByVirtualDesktop: true
        filterByActivity: true
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    function refresh() {
        var out = [];
        for (var i = 0; i < tasks.count; i++) {
            var idx = tasks.makeModelIndex(i);
            if (tasks.data(idx, TaskManager.AbstractTasksModel.IsMinimized))
                continue;
            var g = tasks.data(idx, TaskManager.AbstractTasksModel.Geometry);
            if (g && g.width > 0 && g.height > 0)
                out.push({ x: g.x, y: g.y, width: g.width, height: g.height });
        }
        rects = out;
    }

    Timer {
        id: debounce
        interval: 80
        onTriggered: watcher.refresh()
    }

    Connections {
        target: tasks
        function onDataChanged() { debounce.restart(); }
        function onRowsInserted() { debounce.restart(); }
        function onRowsRemoved() { debounce.restart(); }
        function onModelReset() { debounce.restart(); }
        function onCountChanged() { debounce.restart(); }
    }

    Connections {
        target: virtualDesktopInfo
        function onCurrentDesktopChanged() { debounce.restart(); }
    }

    Component.onCompleted: refresh()
}
