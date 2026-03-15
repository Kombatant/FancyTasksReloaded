/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQml 2.15

import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore

import org.kde.taskmanager 0.1 as TaskManager
import "taskmanager" as TaskManagerApplet

import "code/layout.js" as LayoutManager
import "code/tools.js" as TaskTools


PlasmoidItem {
    id: tasks

    anchors.fill: parent

    property bool supportsLaunchers: true

    property bool vertical: plasmoid.formFactor === PlasmaCore.Types.Vertical
    property bool iconsOnly: plasmoid.configuration.iconOnly
    readonly property bool manualSorting: plasmoid.configuration.sortingStrategy === 1
    readonly property bool effectiveSeparateLaunchers: !manualSorting || iconsOnly || plasmoid.configuration.separateLaunchers
    property bool _reconciling: false
    property bool containsMouse: hoverTracker.hovered
    property bool hoverEffectsActive: hoverTracker.hovered || hoverExitTimer.running
    property real rawHoverPointerX: hoverTracker.point.position.x
    property real rawHoverPointerY: hoverTracker.point.position.y
    property real hoverPointerX: rawHoverPointerX
    property real hoverPointerY: rawHoverPointerY
    property int smallSpacing: Kirigami.Units.smallSpacing
    property int iconSizeSmall: Kirigami.Units.iconSizes.small
    property int iconSizeMedium: Kirigami.Units.iconSizes.medium
    property int defaultFontWidth: Math.max(1, Math.ceil(defaultFontMetrics.advanceWidth))
    property int defaultFontHeight: Math.max(1, Math.ceil(defaultFontMetrics.height))
    property int hoverLayoutRevision: 0
    readonly property real hoverLayoutExtraLength: {
        hoverLayoutRevision;
        let total = 0;

        if ((!plasmoid.configuration.hoverEffectsEnabled && !plasmoid.configuration.hoverBounce)
            || Number(plasmoid.configuration.hoverEffectMode || 0) !== 1) {
            return 0;
        }

        for (let i = 0; i < taskRepeater.count; ++i) {
            const item = taskRepeater.itemAt(i);
            if (!item) {
                continue;
            }

            total += vertical ? item.hoverLayoutExtraHeight : item.hoverLayoutExtraWidth;
        }

        return total;
    }

    property var toolTipOpenedByClick: null

    property QtObject contextMenuComponent: Qt.createComponent("ContextMenu.qml")
    property QtObject pulseAudioComponent: Qt.createComponent("PulseAudio.qml")
    property QtObject mprisSourceComponent: Qt.createComponent("MprisSource.qml")

    property bool needLayoutRefresh: false;
    property variant taskClosedWithMouseMiddleButton: []

    TextMetrics {
        id: defaultFontMetrics
        font: Qt.application.font
        text: "m"
    }

    HoverHandler {
        id: hoverTracker
        target: null
    }

    Behavior on hoverPointerX {
        SmoothedAnimation {
            velocity: 2200
            reversingMode: SmoothedAnimation.Immediate
            maximumEasingTime: 90
        }
    }

    Behavior on hoverPointerY {
        SmoothedAnimation {
            velocity: 2200
            reversingMode: SmoothedAnimation.Immediate
            maximumEasingTime: 90
        }
    }

    preferredRepresentation: fullRepresentation

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumWidth: tasks.vertical ? 0 : LayoutManager.preferredMinWidth()
    Layout.minimumHeight: !tasks.vertical ? 0 : LayoutManager.preferredMinHeight()

//BEGIN TODO: this is not precise enough: launchers are smaller than full tasks

    Layout.preferredWidth: tasks.vertical ? Kirigami.Units.gridUnit * 10 :
                           (LayoutManager.logicalTaskCount() === 0 ? 0.01 : //Return a small non-zero value to make the panel account for the change in size
                           ((LayoutManager.logicalTaskCount() * LayoutManager.preferredMaxWidth()) / LayoutManager.calculateStripes()) + hoverLayoutExtraLength)


    Layout.preferredHeight: !tasks.vertical ? Kirigami.Units.gridUnit * 2 + hoverLayoutExtraLength :
                            (LayoutManager.logicalTaskCount() === 0 ? 0.01 : //Same as above
                            ((LayoutManager.logicalTaskCount() * LayoutManager.preferredMaxHeight()) / LayoutManager.calculateStripes()) + hoverLayoutExtraLength)

//END TODO

    property Item dragSource: null
    property Item dragIgnoredItem: null

    readonly property alias dragIgnoreTimer: _dragIgnoreTimer
    Timer {
        id: _dragIgnoreTimer
        repeat: false
        interval: 750
        onTriggered: tasks.dragIgnoredItem = null
    }

    Timer {
        id: hoverExitTimer
        repeat: false
        interval: 110
    }

    Timer {
        id: hoverLayoutTimer
        repeat: false
        interval: 16
        onTriggered: {
            hoverLayoutRevision++;
            requestLayout();
        }
    }

    signal requestLayout
    signal windowsHovered(variant winIds, bool hovered)
    signal activateWindowView(variant winIds)

    onWidthChanged: {
        taskList.width = LayoutManager.layoutWidth();

        if (plasmoid.configuration.forceStripes) {
            taskList.height = LayoutManager.layoutHeight();
        }
    }

    onHeightChanged: {
        if (plasmoid.configuration.forceStripes) {
            taskList.width = LayoutManager.layoutWidth();
        }

        taskList.height = LayoutManager.layoutHeight();
    }

    onDragSourceChanged: {
        if (dragSource == null) {
            tasksModel.syncLaunchers();
            dragIgnoredItem = null;
            _dragIgnoreTimer.stop();
        }
    }

    onContainsMouseChanged: {
        if (containsMouse) {
            hoverExitTimer.stop();
            hoverPointerX = rawHoverPointerX;
            hoverPointerY = rawHoverPointerY;
        } else {
            hoverExitTimer.restart();
        }

        if (!containsMouse && needLayoutRefresh) {
            LayoutManager.layout(taskRepeater)
            needLayoutRefresh = false;
        }
    }

    onRawHoverPointerXChanged: {
        hoverPointerX = rawHoverPointerX;
    }

    onRawHoverPointerYChanged: {
        hoverPointerY = rawHoverPointerY;
    }

    onHoverPointerXChanged: if (!vertical) refreshHoverLayout()
    onHoverPointerYChanged: if (vertical) refreshHoverLayout()
    onHoverEffectsActiveChanged: refreshHoverLayout()

    TaskManager.TasksModel {
        id: tasksModel

        readonly property int logicalLauncherCount: {
            if (tasks.effectiveSeparateLaunchers) {
                return launcherCount;
            }

            var startupsWithLaunchers = 0;

            for (var i = 0; i < taskRepeater.count; ++i) {
                var item = taskRepeater.itemAt(i);

                if (item && item.m.IsStartup === true && item.m.HasLauncher === true) {
                    ++startupsWithLaunchers;
                }
            }

            return launcherCount + startupsWithLaunchers;
        }

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: plasmoid.screenGeometry || Qt.rect(0, 0, tasks.width, tasks.height)
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: plasmoid.configuration.showOnlyCurrentDesktop
        filterByScreen: plasmoid.configuration.showOnlyCurrentScreen
        filterByActivity: plasmoid.configuration.showOnlyCurrentActivity
        filterNotMinimized: plasmoid.configuration.showOnlyMinimized

        sortMode: sortModeEnumValue(plasmoid.configuration.sortingStrategy)
        launchInPlace: tasks.manualSorting
        separateLaunchers: tasks.effectiveSeparateLaunchers

        groupMode: groupModeEnumValue(plasmoid.configuration.groupingStrategy)
        groupInline: !plasmoid.configuration.groupPopups
        groupingWindowTasksThreshold: (plasmoid.configuration.onlyGroupWhenFull && !iconsOnly
            ? LayoutManager.optimumCapacity(width, height) + 1 : -1)

        onLauncherListChanged: {
            layoutTimer.restart();
            if (!tasks._reconciling) {
                plasmoid.configuration.launchers = launcherList;
            }
        }

        onGroupingAppIdBlacklistChanged: {
            plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist;
        }

        onGroupingLauncherUrlBlacklistChanged: {
            plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
        }

        function sortModeEnumValue(index) {
            switch (index) {
                case 0:
                    return TaskManager.TasksModel.SortDisabled;
                case 1:
                    return TaskManager.TasksModel.SortManual;
                case 2:
                    return TaskManager.TasksModel.SortAlpha;
                case 3:
                    return TaskManager.TasksModel.SortVirtualDesktop;
                case 4:
                    return TaskManager.TasksModel.SortActivity;
                default:
                    return TaskManager.TasksModel.SortDisabled;
            }
        }

        function groupModeEnumValue(index) {
            switch (index) {
                case 0:
                    return TaskManager.TasksModel.GroupDisabled;
                case 1:
                    return TaskManager.TasksModel.GroupApplications;
            }
        }

        Component.onCompleted: {
            launcherList = plasmoid.configuration.launchers;
            groupingAppIdBlacklist = plasmoid.configuration.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = plasmoid.configuration.groupingLauncherUrlBlacklist;

            // Only hook up view only after the above churn is done.
            taskRepeater.model = tasksModel;
        }
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.ActivityInfo {
        id: activityInfo
        readonly property string nullUuid: "00000000-0000-0000-0000-000000000000"
    }

    TaskManagerApplet.Backend {
        id: backend

        taskManagerItem: tasks
        highlightWindows: plasmoid.configuration.highlightWindows

        onAddLauncher: {
            tasks.addLauncher(url);
        }
    }

    Connections {
        target: tasksModel
        function onCountChanged() {
            console.log("[fancytasks_rld] tasksModel.countChanged; count=", tasksModel.count,
                        "launcherCount=", tasksModel.launcherCount);
            precacheTimer.restart();
        }
        // dataChanged fires when a model row's roles change *without*
        // adding or removing rows — e.g. a pinned launcher transforming
        // into a running window at startup.  The Repeater does NOT emit
        // onItemAdded for such changes, so the layout would never be
        // recalculated.  Restarting the zero-interval layoutTimer
        // batches rapid-fire dataChanged signals into a single relayout.
        function onDataChanged(topLeft, bottomRight, roles) {
            console.log("[fancytasks_rld] tasksModel.dataChanged; rows",
                        topLeft.row, "-", bottomRight.row);
            layoutTimer.restart();
            // Reset the settle timer so we wait for the model to stop changing
            // before re-applying launcher positions.
            if (launcherReconcileTimer.running) {
                launcherReconcileTimer.restart();
            }
        }
        function onRowsMoved() {
            console.log("[fancytasks_rld] tasksModel.rowsMoved");
            layoutTimer.restart();
            if (launcherReconcileTimer.running) {
                launcherReconcileTimer.restart();
            }
        }
    }

    Timer {
        id: precacheTimer
        interval: 300
        repeat: false
        onTriggered: backend.precacheAllLaunchers(tasksModel)
    }

    Timer {
        id: startupPrecacheTimer
        interval: 1000
        repeat: false
        running: true
        onTriggered: backend.precacheAllLaunchers(tasksModel)
    }

    // Work around a race condition in the C++ TasksModel where, during
    // startup, windows may be matched to the wrong launchers because
    // KWin hasn't provided complete appId data yet.  After the model
    // has been quiet for 1.5 s we detect misplaced window tasks
    // (windows whose model position doesn't match their launcher list
    // position) and correct them via tasksModel.move(), then re-apply
    // the saved launcher list to restore the correct sort order.
    Timer {
        id: launcherReconcileTimer
        interval: 100
        repeat: false
        running: true          // starts ticking at Component creation
        onTriggered: {
            console.log("[fancytasks_rld] launcherReconcileTimer fired — checking for misplaced tasks");
            var launchers = plasmoid.configuration.launchers;

            // Build URL → expected launcher position map.
            // The launcher list may contain preferred:// URLs (e.g.
            // preferred://filemanager) that the model resolves to the
            // actual desktop file URL.  We build the map from the exact
            // launcher URLs first, then match unresolved preferred://
            // entries with model items whose LauncherUrlWithoutIcon
            // doesn't appear in the list.
            var urlToPos = {};
            var preferredPositions = [];  // positions of preferred:// entries
            for (var k = 0; k < launchers.length; k++) {
                urlToPos[launchers[k]] = k;
                if (launchers[k].indexOf("preferred://") === 0) {
                    preferredPositions.push(k);
                }
            }

            // Resolve preferred:// entries by finding model items whose
            // resolved URL isn't already in the map.
            if (preferredPositions.length > 0) {
                var unmatchedItems = [];
                for (var i = 0; i < taskRepeater.count; i++) {
                    var item = taskRepeater.itemAt(i);
                    if (item && item.m && item.m.HasLauncher) {
                        var resolvedUrl = item.m.LauncherUrlWithoutIcon;
                        if (resolvedUrl && urlToPos[resolvedUrl] === undefined) {
                            unmatchedItems.push(resolvedUrl);
                        }
                    }
                }
                // Match each unmatched resolved URL to a preferred://
                // position.  With ≤2 preferred entries this is reliable.
                for (var p = 0; p < preferredPositions.length && p < unmatchedItems.length; p++) {
                    urlToPos[unmatchedItems[p]] = preferredPositions[p];
                    console.log("[fancytasks_rld] reconcile: resolved preferred pos "
                              + preferredPositions[p] + " → " + unmatchedItems[p]);
                }
            }

            // Block config saves during reconciliation
            tasks._reconciling = true;

            var maxPasses = 20;
            var pass = 0;
            var moved = true;
            while (moved && pass < maxPasses) {
                moved = false;
                pass++;
                for (var i = 0; i < taskRepeater.count; i++) {
                    var item = taskRepeater.itemAt(i);
                    if (!item || !item.m) continue;
                    if (!item.m.IsWindow || !item.m.HasLauncher) continue;
                    var url = item.m.LauncherUrlWithoutIcon;
                    if (!url || urlToPos[url] === undefined) continue;
                    var expectedPos = urlToPos[url];
                    if (i !== expectedPos) {
                        console.log("[fancytasks_rld] reconcile: MOVING " + item.m.AppName
                                  + " from " + i + " to " + expectedPos);
                        tasksModel.move(i, expectedPos);
                        moved = true;
                        break; // restart scan — indices shifted
                    }
                }
            }

            // Re-apply the original launcher list to undo any corruption
            // from move(), then allow config saves again.
            tasksModel.launcherList = launchers;
            tasks._reconciling = false;

            console.log("[fancytasks_rld] reconcile done — " + pass + " passes");
        }
    }

    MprisUnavailable {
        id: mprisUnavailable
    }

    Loader {
        id: mprisSourceLoader
        active: true
        source: mprisSourceComponent.status === Component.Ready ? "MprisSource.qml" : "MprisUnavailable.qml"
    }

    readonly property QtObject mpris2Source: mprisSourceLoader.item ? mprisSourceLoader.item : mprisUnavailable

    Loader {
        id: pulseAudio
        sourceComponent: pulseAudioComponent
        active: plasmoid.configuration.indicateAudioStreams && pulseAudioComponent.status === Component.Ready
    }

    Timer {
        id: iconGeometryTimer

        interval: 500
        repeat: false

        onTriggered: {
            TaskTools.publishIconGeometries(taskList.children);
        }
    }

    Timer {
        id: updateTimer
        interval: 500
        repeat: false
        onTriggered: {
            TaskTools.publishIconGeometries(taskList.children);
            taskList.layout();
        }
    }

    Binding {
        target: plasmoid
        property: "status"
        value: (tasksModel.anyTaskDemandsAttention && plasmoid.configuration.unhideOnAttention
            ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.PassiveStatus)
        restoreMode: Binding.RestoreBinding
    }

    Connections {
        target: plasmoid

        function onUserConfiguringChanged() {
            if (plasmoid.userConfiguring && groupDialog) {
                groupDialog.visible = false;
            }
        }

        function onLocationChanged() {
            // This is on a timer because the panel may not have
            // settled into position yet when the location prop-
            // erty updates.
            iconGeometryTimer.start();
        }
    }

    Connections {
        target: plasmoid.configuration

        function onLaunchersChanged() {
            tasksModel.launcherList = plasmoid.configuration.launchers
        }
        function onGroupingAppIdBlacklistChanged() {
            tasksModel.groupingAppIdBlacklist = plasmoid.configuration.groupingAppIdBlacklist;
        }
        function onGroupingLauncherUrlBlacklistChanged() {
            tasksModel.groupingLauncherUrlBlacklist = plasmoid.configuration.groupingLauncherUrlBlacklist;
        }
        function onValueChanged() {
            // On a timer to make sure all of the layout changes are applied.
            updateTimer.start()
        }

    }

    TaskManagerApplet.DragHelper {
        id: dragHelper

        dragIconSize: Kirigami.Units.iconSizes.medium
    }

    KSvg.FrameSvgItem {
        id: taskFrame

        visible: false;

        imagePath: "widgets/tasks";
        prefix: "normal"
    }

    KSvg.Svg {
        id: taskSvg

        imagePath: "widgets/tasks"
    }

    MouseHandler {
        id: mouseHandler

        anchors.fill: parent

        target: taskList

        onUrlsDropped: {
            // If all dropped URLs point to application desktop files, we'll add a launcher for each of them.
            var createLaunchers = urls.every(function (item) {
                return backend.isApplication(item)
            });

            if (createLaunchers) {
                urls.forEach(function (item) {
                    addLauncher(item);
                });
                return;
            }

            if (!hoveredItem) {
                return;
            }

            // DeclarativeMimeData urls is a QJsonArray but requestOpenUrls expects a proper QList<QUrl>.
            var urlsList = backend.jsonArrayToUrlList(urls);

            // Otherwise we'll just start a new instance of the application with the URLs as argument,
            // as you probably don't expect some of your files to open in the app and others to spawn launchers.
            tasksModel.requestOpenUrls(hoveredItem.modelIndex(), urlsList);
        }
    }

    ToolTipDelegate {
        id: openWindowToolTipDelegate
        visible: false
    }

    ToolTipDelegate {
        id: pinnedAppToolTipDelegate
        visible: false
    }

    TaskList {
        id: taskList
        spacing: plasmoid.configuration.taskSpacingSize

        anchors {
            left: parent.left
            leftMargin: plasmoid.configuration.reverseMode && !vertical ? (LayoutManager.logicalTaskCount() + tasksModel.logicalLauncherCount) * plasmoid.configuration.taskSpacingSize : 0
            top: parent.top
        }

        onWidthChanged: LayoutManager.layout(taskRepeater)
        onHeightChanged: LayoutManager.layout(taskRepeater)

        flow: {
            if (tasks.vertical) {
                return plasmoid.configuration.forceStripes ? Flow.LeftToRight : Flow.TopToBottom
            }
            return plasmoid.configuration.forceStripes ? Flow.TopToBottom : Flow.LeftToRight
        }

        onAnimatingChanged: {
            if (!animating) {
                TaskTools.publishIconGeometries(children);
            }
        }

        function layout() {
            console.log("[fancytasks_rld] taskList.layout() called");
            taskList.width = LayoutManager.layoutWidth();
            taskList.height = LayoutManager.layoutHeight();
            LayoutManager.layout(taskRepeater);
            LayoutManager
        }

        Timer {
            id: layoutTimer

            interval: 0
            repeat: false

            onTriggered: {
                console.log("[fancytasks_rld] layoutTimer fired");
                taskList.layout();
            }
        }

        Repeater {
            id: taskRepeater

            delegate: Task {
                readonly property bool isSubTask: false
            }
            onItemAdded: {
                console.log("[fancytasks_rld] Repeater.onItemAdded; index=", index);
                taskList.layout()

            }
            onItemRemoved: {
                if (tasks.containsMouse && index != taskRepeater.count &&
                    item.winIdList && item.winIdList.length > 0 &&
                    taskClosedWithMouseMiddleButton.indexOf(item.winIdList[0]) > -1) {
                    needLayoutRefresh = true;
                } else {
                    taskList.layout();
                }
                taskClosedWithMouseMiddleButton = [];
            }
        }
    }

    readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
    property GroupDialog groupDialog: null

    function hasLauncher(url: url) : bool {
        return tasksModel.launcherPosition(url) != -1;
    }

    function addLauncher(url: url) : void {
        if (plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestAddLauncher(url);
        }
    }

    // This is called by plasmashell in response to a Meta+number shortcut.
    function activateTaskAtIndex(index) {
        if (typeof index !== "number") {
            return;
        }

        var task = taskRepeater.itemAt(index);
        if (task) {
            /**
             * BUG 452187: when activating a task from keyboard, there is no
             * containsMouse changed signal, so we need to update the tooltip
             * properties here.
             */
            if (plasmoid.configuration.showToolTips
                && plasmoid.configuration.groupedTaskVisualization === 1) {
                task.toolTipAreaItem.updateMainItemBindings();
            }

            TaskTools.activateTask(task.modelIndex(), task.m, null, task);
        }
    }

    function resetDragSource() {
        dragSource = null;
    }

    function refreshHoverLayout() {
        if (Number(plasmoid.configuration.hoverEffectMode || 0) !== 1
            || (!plasmoid.configuration.hoverEffectsEnabled && !plasmoid.configuration.hoverBounce)) {
            return;
        }

        hoverLayoutTimer.restart();
    }

    function createContextMenu(rootTask, modelIndex, args = {}) {
        if (contextMenuComponent.status !== Component.Ready) {
            return null;
        }

        const initialArgs = Object.assign(args, {
            visualParent: rootTask,
            modelIndex,
            mpris2Source,
            backend,
        });
        return contextMenuComponent.createObject(rootTask, initialArgs);
    }

    Component.onCompleted: {
        tasks.requestLayout.connect(layoutTimer.restart);
        tasks.requestLayout.connect(iconGeometryTimer.restart);
        tasks.windowsHovered.connect(backend.windowsHovered);
        tasks.activateWindowView.connect(backend.activateWindowView);
        dragHelper.dropped.connect(resetDragSource);
    }
}
