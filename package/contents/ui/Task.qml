/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15

import org.kde.ksvg as KSvg
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.draganddrop 2.0
import org.kde.kirigami 2.20 as Kirigami

import "taskmanager" as TaskManagerApplet

import QtQuick.Layouts 1.3

import Qt5Compat.GraphicalEffects

import "code/layout.js" as LayoutManager
import "code/tools.js" as TaskTools

MouseArea {
    id: task

    activeFocusOnTab: true

    height: Math.max(tasks.defaultFontHeight, Kirigami.Units.iconSizes.medium) + LayoutManager.verticalMargins()

    visible: false

    LayoutMirroring.enabled: (Qt.application.layoutDirection == Qt.RightToLeft)
    LayoutMirroring.childrenInherit: (Qt.application.layoutDirection == Qt.RightToLeft)

    readonly property var m: model
    readonly property bool badgeDebugEnabled: appName === "Viber"
        || appName === "Zen Browser"
        || appId.toLowerCase() === "viber"
        || appId.toLowerCase() === "zen"
    
    readonly property int pid: model.AppPid !== undefined ? model.AppPid : 0
    readonly property string appName: model.AppName || ""
    readonly property string appId: model.AppId ? model.AppId.replace(/\.desktop$/, "") : ""
    readonly property variant winIdList: model.WinIdList
    readonly property var effectiveIconSource: {
        if (model.decoration) {
            return model.decoration;
        }

        var launcherIcon = backend.desktopEntryIcon(model.LauncherUrlWithoutIcon);
        if (launcherIcon) {
            return launcherIcon;
        }

        if (appId) {
            return appId;
        }

        return "application-x-executable";
    }
    property int itemIndex: index
    property bool inPopup: false
    property bool isWindow: model.IsWindow === true
    property int childCount: model.ChildCount !== undefined ? model.ChildCount : 0
    property int previousChildCount: 0
    property alias labelText: label.text
    property bool pressed: false
    property int pressX: -1
    property int pressY: -1
    property bool dragging: false
    property int attentionBadgeCount: 0
    property bool lastDemandingAttention: model.IsDemandingAttention === true
    property QtObject contextMenu: null
    property int wheelDelta: 0
    readonly property bool smartLauncherEnabled: !inPopup && model.IsStartup !== true
    property QtObject smartLauncherItem: null
    readonly property Component smartLauncherItemComponent: Qt.createComponent("taskmanager/SmartLauncherItem.qml")
    property alias toolTipAreaItem: toolTipArea
    property alias audioStreamIconLoaderItem: audioStreamIconLoader

    readonly property bool isMetro: plasmoid.configuration.indicatorStyle === 0
    readonly property bool isCiliora: plasmoid.configuration.indicatorStyle === 1
    readonly property bool isDashes: plasmoid.configuration.indicatorStyle === 2
    readonly property bool isDots: plasmoid.configuration.indicatorStyle === 3
    readonly property bool customIndicatorsEnabled: tasks.indicatorsForcedEnabled

    property Item audioStreamOverlay
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    readonly property bool audioIndicatorsEnabled: plasmoid.configuration.indicateAudioStreams
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(function (item) {
        return !item.corked
    })
    readonly property bool muted: hasAudioStream && audioStreams.every(function (item) {
        return item.muted
    })
    readonly property int effectiveBadgeCount: {
        if (task.smartLauncherItem && task.smartLauncherItem.countVisible) {
            return Math.max(task.smartLauncherItem.count, attentionBadgeCount);
        }

        if (attentionBadgeCount > 0) {
            return attentionBadgeCount;
        }

        return model.IsDemandingAttention === true ? 1 : 0;
    }
    readonly property bool effectiveBadgeVisible: plasmoid.configuration.notificationBadges === true
        && effectiveBadgeCount > 0

    readonly property bool highlighted: (inPopup && activeFocus) || (!inPopup && containsMouse)
        || (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)
        || (!!tasks.groupDialog && tasks.groupDialog.visualParent === task)

    property string tintColor: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) ===
                                Kirigami.ColorUtils.Dark ?
                                "#ffffff" : "#000000"
    readonly property color iconShadowColor: {
        const background = Kirigami.Theme.backgroundColor;
        const luminance = (background.r * 0.2126) + (background.g * 0.7152) + (background.b * 0.0722);

        if (luminance <= 0.28) {
            return Qt.rgba(1, 1, 1, 0.34);
        }

        if (luminance >= 0.72) {
            return Qt.rgba(0, 0, 0, 0.34);
        }

        return luminance >= 0.5 ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(1, 1, 1, 0.28);
    }
    readonly property int iconShadowType: plasmoid.configuration.floatingIconShadowType || 0
    readonly property bool hoverEffectsEnabled: !!plasmoid.configuration.hoverEffectsEnabled || !!plasmoid.configuration.hoverBounce
    readonly property int hoverEffectMode: Number(plasmoid.configuration.hoverEffectMode || 0)
    readonly property bool hoverBounceEnabled: hoverEffectsEnabled && hoverEffectMode === 0 && highlighted
    readonly property bool hoverMagnifyEnabled: hoverEffectsEnabled && hoverEffectMode === 1 && !inPopup && tasks.hoverEffectsActive
    readonly property real hoverMagnifyProgress: hoverEffectProgress(icon)
    readonly property real hoverMaxPanelThicknessExtra: hoverEffectsEnabled && hoverEffectMode === 1 && !inPopup && icon
        ? hoverPanelThicknessExtraForProgress(icon, 1)
        : 0
    readonly property bool iconFrameModeEnabled: !hoverEffectsEnabled
    readonly property bool iconFrameHovered: !inPopup && containsMouse
    readonly property bool iconFrameActive: !inPopup && model.IsActive === true
    readonly property bool iconFrameVisible: iconFrameModeEnabled && (iconFrameHovered || iconFrameActive)
    readonly property bool showStaticIconFrame: iconFrameModeEnabled && iconFrameVisible
    readonly property color iconFrameAccentColor: Kirigami.Theme.highlightColor
    readonly property bool darkPanel: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor)
        === Kirigami.ColorUtils.Dark
    z: hoverEffectsEnabled ? Math.round((hoverBounceEnabled ? 1 : hoverMagnifyProgress) * 100) : 0

    function iconFrameFillColor(alphaScale) {
        const accent = task.iconFrameAccentColor;
        const scale = alphaScale === undefined ? 1 : alphaScale;
        const hoverAndActiveAlpha = task.darkPanel ? 0.30 : 0.24;
        const activeAlpha = task.darkPanel ? 0.22 : 0.17;
        const hoverAlpha = task.darkPanel ? 0.14 : 0.11;

        if (task.iconFrameHovered && task.iconFrameActive) {
            return Qt.rgba(accent.r, accent.g, accent.b, hoverAndActiveAlpha * scale);
        }

        if (task.iconFrameActive) {
            return Qt.rgba(accent.r, accent.g, accent.b, activeAlpha * scale);
        }

        return Qt.rgba(accent.r, accent.g, accent.b, hoverAlpha * scale);
    }

    function iconFrameBorderColor(alphaScale) {
        const accent = task.iconFrameAccentColor;
        const scale = alphaScale === undefined ? 1 : alphaScale;
        const hoverAndActiveAlpha = task.darkPanel ? 1.0 : 0.98;
        const activeAlpha = task.darkPanel ? 0.88 : 0.84;
        const hoverAlpha = task.darkPanel ? 0.72 : 0.68;

        if (task.iconFrameHovered && task.iconFrameActive) {
            return Qt.rgba(accent.r, accent.g, accent.b, hoverAndActiveAlpha * scale);
        }

        if (task.iconFrameActive) {
            return Qt.rgba(accent.r, accent.g, accent.b, activeAlpha * scale);
        }

        return Qt.rgba(accent.r, accent.g, accent.b, hoverAlpha * scale);
    }

    function iconFrameGlowColor(alphaScale) {
        const accent = task.iconFrameAccentColor;
        const scale = alphaScale === undefined ? 1 : alphaScale;

        if (task.iconFrameHovered && task.iconFrameActive) {
            return Qt.rgba(accent.r, accent.g, accent.b, (task.darkPanel ? 0.40 : 0.24) * scale);
        }

        if (task.iconFrameActive) {
            return Qt.rgba(accent.r, accent.g, accent.b, (task.darkPanel ? 0.28 : 0.18) * scale);
        }

        return Qt.rgba(accent.r, accent.g, accent.b, (task.darkPanel ? 0.16 : 0.11) * scale);
    }

    function hoverEffectProgress(item) {
        if (!hoverMagnifyEnabled || !item) {
            return 0;
        }

        const pointer = tasks.vertical ? tasks.hoverPointerY : tasks.hoverPointerX;
        return hoverEffectProgressForPointer(item, pointer);
    }

    function hoverPointerForItem(item) {
        if (!item) {
            return 0;
        }

        const center = item.mapToItem(tasks, item.width / 2, item.height / 2);
        return tasks.vertical ? center.y : center.x;
    }

    function hoverEffectProgressForPointer(item, pointer) {
        if (!item) {
            return 0;
        }

        const axisCenter = hoverPointerForItem(item);
        const span = tasks.vertical ? item.height : item.width;
        const influenceRadius = Math.max(span * 2.6, Kirigami.Units.gridUnit * 4);
        const normalized = Math.max(0, 1 - (Math.abs(axisCenter - pointer) / influenceRadius));

        return Math.sin(normalized * Math.PI / 2);
    }

    function hoverScaleForItem(item) {
        if (hoverBounceEnabled) {
            return 1.06;
        }

        return 1 + (hoverEffectProgress(item) * 0.5);
    }

    function hoverPanelThicknessExtraForProgress(item, progress) {
        if (!item || progress <= 0) {
            return 0;
        }

        const span = tasks.vertical ? item.width : item.height;
        const scaleExtra = span * 0.25 * progress;
        const offsetExtra = span * 0.32 * progress;
        return scaleExtra + offsetExtra;
    }

    function hoverOffsetForItem(item, axis) {
        if (!item) {
            return 0;
        }

        const span = axis === "x" ? item.width : item.height;
        let amount = 0;

        if (hoverBounceEnabled) {
            amount = Math.min(12, span * 0.12);
        } else {
            amount = span * 0.32 * hoverEffectProgress(item);
        }

        if (amount <= 0) {
            return 0;
        }

        if (axis === "x") {
            if (plasmoid.location === PlasmaCore.Types.LeftEdge) {
                return -amount;
            }

            if (plasmoid.location === PlasmaCore.Types.RightEdge) {
                return amount;
            }

            return 0;
        }

        if (plasmoid.location === PlasmaCore.Types.BottomEdge) {
            return -amount;
        }

        if (plasmoid.location === PlasmaCore.Types.TopEdge) {
            return amount;
        }

        return 0;
    }

    Accessible.name: model.display
    Accessible.description: model.display ? i18n("Activate %1", model.display) : ""
    Accessible.role: Accessible.Button


    onHighlightedChanged: {
        // ensure it doesn't get stuck with a window highlighted
        console.log("[fancytasks_rld][Task] onHighlightedChanged; highlighted=", highlighted, "frame.isHovered=", frame.isHovered, "plasmoid.location=", plasmoid.location);
        // also print current transform state if available
        try { console.log("[fancytasks_rld][Task] transform: hoverTranslate.x=", hoverTranslate.x, "hoverScale=", hoverScale.xScale); } catch (e) {}
        backend.cancelHighlightWindows();
    }

    function showToolTip() {
        toolTipArea.showToolTip();
    }
    function hideToolTipTemporarily() {
        toolTipArea.hideToolTip();
    }

    function ensureSmartLauncherItem() {
        if (!smartLauncherEnabled || smartLauncherItem) {
            return;
        }

        if (smartLauncherItemComponent.status !== Component.Ready) {
            console.log("[fancytasks_badge][Task] SmartLauncher component not ready",
                        "appName=", appName,
                        "status=", smartLauncherItemComponent.status,
                        "error=", smartLauncherItemComponent.errorString());
            return;
        }

        const smartLauncher = smartLauncherItemComponent.createObject(task);
        if (!smartLauncher) {
            console.log("[fancytasks_badge][Task] SmartLauncher createObject failed",
                        "appName=", appName,
                        "error=", smartLauncherItemComponent.errorString());
            return;
        }

        smartLauncher.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
        smartLauncher.appId = Qt.binding(() => task.appId);
        smartLauncher.appName = Qt.binding(() => task.appName);
        smartLauncher.isActiveWindow = Qt.binding(() => model.IsActive === true);

        smartLauncherItem = smartLauncher;
    }

    function scheduleActiveBadgeReset() {
        activeBadgeResetTimer.restart();
    }

    function cancelActiveBadgeReset() {
        activeBadgeResetTimer.stop();
    }

    function clearAttentionBadgeState(reason) {
        attentionBadgeCount = 0;
        lastDemandingAttention = false;
        if (badgeDebugEnabled) {
            console.log("[fancytasks_badge][Task] clearAttentionBadgeState",
                        "reason=", reason,
                        "appName=", appName,
                        "attentionBadgeCount=", attentionBadgeCount,
                        "lastDemandingAttention=", lastDemandingAttention);
        }
    }

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton

    Timer {
        id: activeBadgeResetTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (model.IsActive === true) {
                clearAttentionBadgeState("activeTimer");
            }
        }
    }

    onPidChanged: updateAudioStreams({delay: false})
    onAppNameChanged: updateAudioStreams({delay: false})

    onIsWindowChanged: {
        console.log("[fancytasks_rld][Task] onIsWindowChanged; isWindow=", isWindow,
                    "appName=", appName, "itemIndex=", itemIndex,
                    "IsLauncher=", model.IsLauncher, "HasLauncher=", model.HasLauncher);
        if (!isWindow) {
            clearAttentionBadgeState("notWindow");
        }
        if (isWindow) {
            taskInitComponent.createObject(task);
        }
        // A launcher→window (or window→launcher) transform is a data-only
        // change in the model — no rows are added or removed, so the
        // Repeater's onItemAdded never fires.  Without an explicit layout
        // request the item keeps its stale size/position from the previous
        // layout() pass, which is why the last pinned open app could appear
        // in the wrong spot after a plasmashell restart.
        if (!inPopup) {
            tasks.requestLayout();
        }
    }

    onChildCountChanged: {
        if (childCount > previousChildCount) {
            tasksModel.requestPublishDelegateGeometry(modelIndex(), backend.globalRect(task), task);
        }

        previousChildCount = childCount;
    }

    onItemIndexChanged: {
        console.log("[fancytasks_rld][Task] onItemIndexChanged; itemIndex=", itemIndex,
                    "appName=", appName, "isWindow=", isWindow,
                    "IsLauncher=", model.IsLauncher);
        hideToolTipTemporarily();

        if (!inPopup && !tasks.vertical
            && (LayoutManager.calculateStripes() > 1 || !tasks.effectiveSeparateLaunchers)) {
            tasks.requestLayout();
        }
    }

    onContainsMouseChanged:  {
        console.log("[fancytasks_rld][Task] onContainsMouseChanged; containsMouse=", containsMouse, "task.highlighted=", highlighted);
        if (containsMouse) {
            if (inPopup) {
                forceActiveFocus();
            }
        } else {
            pressed = false;
        }
    }

    onPressed: function(mouse) {
        if (mouse.button == Qt.LeftButton || mouse.button == Qt.MiddleButton || mouse.button === Qt.BackButton || mouse.button === Qt.ForwardButton) {
            pressed = true;
            pressX = mouse.x;
            pressY = mouse.y;
        }
    }

    onPressAndHold: function(mouse) {
        if (mouse.button !== Qt.LeftButton) {
            return;
        }

        /* TODO: make press and hold to open menu exclusive to touch.
         * I (ndavis) tried `if (lastDeviceType & ~(PointerDevice.Mouse | PointerDevice.TouchPad))`
         * with a TapHandler. lastDeviceType was gotten from the EventPoint argument of the
         * grabChanged() signal. ngraham said it wouldn't work because it was preventing single
         * taps on touch. I didn't have a touch screen to test it with.
         */
        // When we're a launcher, there's no window controls, so we can show all
        // places without the menu getting super huge.
        if (model.IsLauncher === true) {
            showContextMenu({showAllPlaces: true})
        } else {
            showContextMenu();
        }
    }

    onReleased: function(mouse) {
        if (dragging) {
            dragging = false;
            tasks.dragSource = null;
            pressed = false;
            pressX = -1;
            pressY = -1;
            return;
        }

        if (pressed) {
            if (mouse.button == Qt.MiddleButton) {
                if (plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.NewInstance) {
                    backend.requestNewInstance(modelIndex(), model.LauncherUrlWithoutIcon);
                } else if (plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.Close) {
                    tasks.taskClosedWithMouseMiddleButton = winIdList.slice()
                    tasksModel.requestClose(modelIndex());
                } else if (plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleMinimized) {
                    tasksModel.requestToggleMinimized(modelIndex());
                } else if (plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleGrouping) {
                    tasksModel.requestToggleGrouping(modelIndex());
                } else if (plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.BringToCurrentDesktop) {
                    tasksModel.requestVirtualDesktops(modelIndex(), [virtualDesktopInfo.currentDesktop]);
                }
            } else if (mouse.button == Qt.LeftButton) {
                if (plasmoid.configuration.showToolTips && toolTipArea.active) {
                    hideToolTipTemporarily();
                }
                TaskTools.activateTask(modelIndex(), model, mouse.modifiers, task);
            } else if (mouse.button === Qt.BackButton || mouse.button === Qt.ForwardButton) {
                var player = mpris2Source.playerForLauncherUrl(model.LauncherUrlWithoutIcon, model.AppPid);
                if (player) {
                    if (mouse.button === Qt.BackButton) {
                        mpris2Source.goPrevious(player);
                    } else {
                        mpris2Source.goNext(player);
                    }
                } else {
                    mouse.accepted = false;
                }
            }

            backend.cancelHighlightWindows();
        }

        pressed = false;
        pressX = -1;
        pressY = -1;
    }

    onPositionChanged: function(mouse) {
        // mouse.button is always 0 here, hence checking with mouse.buttons
        if (!dragging && pressX != -1 && mouse.buttons == Qt.LeftButton
                && dragHelper.isDrag(pressX, pressY, mouse.x, mouse.y)) {
            dragging = true;
            tasks.dragSource = task;
        }

        if (dragging) {
            if (taskList.animating) {
                return;
            }

            var taskListPos = mapToItem(taskList, mouse.x, mouse.y);
            var above = taskList.childAt(taskListPos.x, taskListPos.y);

            if (!above || above === task) {
                return;
            }

            // Prevent oscillation when dragging a small launcher over a larger task
            if (!tasks.effectiveSeparateLaunchers
                    && task.m.IsLauncher === true && above.m.IsLauncher !== true
                    && above === tasks.dragIgnoredItem) {
                return;
            } else {
                tasks.dragIgnoredItem = null;
            }

            if (plasmoid.configuration.sortingStrategy === 1
                    && above.itemIndex !== undefined) {
                var insertAt = TaskTools.insertIndexAt(above, taskListPos.x, taskListPos.y);

                if (task.itemIndex !== insertAt) {
                    tasksModel.move(task.itemIndex, insertAt);

                    tasks.dragIgnoredItem = above;
                    tasks.dragIgnoreTimer.restart();
                }
            }
        }
    }

    onWheel: function(wheel) {
        if (plasmoid.configuration.wheelEnabled && (!inPopup || !groupDialog.overflowing)) {
            wheelDelta = TaskTools.wheelActivateNextPrevTask(task, wheelDelta, wheel.angleDelta.y);
        } else {
            wheel.accepted = false;
        }
    }

    onSmartLauncherEnabledChanged: {
        ensureSmartLauncherItem();
    }

    onHasAudioStreamChanged: {
        audioStreamIconLoader.active = hasAudioStream && audioIndicatorsEnabled;
    }

    onAudioIndicatorsEnabledChanged: {
        audioStreamIconLoader.active = hasAudioStream && audioIndicatorsEnabled;

        if (audioIndicatorsEnabled) {
            updateAudioStreams({delay: false});
        } else {
            task.audioStreams = [];
        }
    }

    Connections {
        target: task
        function onMChanged() {
            const demandingAttention = model.IsDemandingAttention === true;
            if (badgeDebugEnabled) {
                console.log("[fancytasks_badge][Task] onMChanged",
                            "appName=", appName,
                            "itemIndex=", itemIndex,
                            "IsActive=", model.IsActive,
                            "IsDemandingAttention=", demandingAttention,
                            "attentionBadgeCount=", attentionBadgeCount,
                            "lastDemandingAttention=", lastDemandingAttention,
                            "smartCount=", task.smartLauncherItem ? task.smartLauncherItem.count : -1,
                            "effectiveBadgeCount=", effectiveBadgeCount);
            }
            if (model.IsActive === true) {
                if (demandingAttention) {
                    cancelActiveBadgeReset();
                    lastDemandingAttention = false;
                    if (badgeDebugEnabled) {
                        console.log("[fancytasks_badge][Task] activeDemandingAttentionCycle",
                                    "appName=", appName,
                                    "attentionBadgeCount=", attentionBadgeCount,
                                    "lastDemandingAttention=", lastDemandingAttention);
                    }
                    return;
                }

                scheduleActiveBadgeReset();
                return;
            }

            cancelActiveBadgeReset();

            if (!demandingAttention) {
                lastDemandingAttention = false;
            }
        }
    }

    Connections {
        target: tasksModel
        function onDataChanged(topLeft, bottomRight) {
            if (!task.isWindow || itemIndex < topLeft.row || itemIndex > bottomRight.row) {
                return;
            }

            if (badgeDebugEnabled) {
                console.log("[fancytasks_badge][Task] tasksModel.onDataChanged",
                            "appName=", appName,
                            "rows=", topLeft.row, "-", bottomRight.row,
                            "itemIndex=", itemIndex,
                            "IsActive=", model.IsActive,
                            "IsDemandingAttention=", model.IsDemandingAttention,
                            "attentionBadgeCount(before)=", attentionBadgeCount,
                            "lastDemandingAttention(before)=", lastDemandingAttention,
                            "smartCount=", task.smartLauncherItem ? task.smartLauncherItem.count : -1,
                            "effectiveBadgeCount=", effectiveBadgeCount);
            }

            if (model.IsActive === true) {
                if (model.IsDemandingAttention === true) {
                    cancelActiveBadgeReset();
                    lastDemandingAttention = false;
                    if (badgeDebugEnabled) {
                        console.log("[fancytasks_badge][Task] activeDemandingAttentionCycle",
                                    "appName=", appName,
                                    "attentionBadgeCount=", attentionBadgeCount,
                                    "lastDemandingAttention=", lastDemandingAttention);
                    }
                    return;
                }

                scheduleActiveBadgeReset();
                if (badgeDebugEnabled) {
                    console.log("[fancytasks_badge][Task] scheduledResetBecauseActive",
                                "appName=", appName,
                                "attentionBadgeCount=", attentionBadgeCount,
                                "lastDemandingAttention=", lastDemandingAttention);
                }
                return;
            }

            cancelActiveBadgeReset();

            const demandingAttention = model.IsDemandingAttention === true;
            if (!demandingAttention) {
                lastDemandingAttention = false;
                if (badgeDebugEnabled) {
                    console.log("[fancytasks_badge][Task] clearDemandingAttention",
                                "appName=", appName,
                                "attentionBadgeCount=", attentionBadgeCount,
                                "lastDemandingAttention=", lastDemandingAttention);
                }
                return;
            }

            if (lastDemandingAttention) {
                if (badgeDebugEnabled) {
                    console.log("[fancytasks_badge][Task] ignoredRepeatedDemandingAttention",
                                "appName=", appName,
                                "attentionBadgeCount=", attentionBadgeCount);
                }
                return;
            }

            lastDemandingAttention = true;
            attentionBadgeCount++;
            if (badgeDebugEnabled) {
                console.log("[fancytasks_badge][Task] incrementAttentionBadgeCount",
                            "appName=", appName,
                            "attentionBadgeCount=", attentionBadgeCount,
                            "effectiveBadgeCount=", effectiveBadgeCount);
            }
        }
    }

    function hexToHSL(hex) {
    var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
        let r = parseInt(result[1], 16);
        let g = parseInt(result[2], 16);
        let b = parseInt(result[3], 16);
        r /= 255, g /= 255, b /= 255;
        var max = Math.max(r, g, b), min = Math.min(r, g, b);
        var h, s, l = (max + min) / 2;
        if(max == min){
        h = s = 0; // achromatic
        }else{
        var d = max - min;
        s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        switch(max){
            case r: h = (g - b) / d + (g < b ? 6 : 0); break;
            case g: h = (b - r) / d + 2; break;
            case b: h = (r - g) / d + 4; break;
        }
        h /= 6;
        }
    var HSL = new Object();
    HSL['h']=h;
    HSL['s']=s;
    HSL['l']=l;
    return HSL;
    }

    Keys.onReturnPressed: function(event) {
        TaskTools.activateTask(modelIndex(), model, event.modifiers, task)
    }
    Keys.onEnterPressed: function(event) {
        Keys.onReturnPressed(event);
    }
    Keys.onSpacePressed: function(event) {
        Keys.onReturnPressed(event);
    }

    function modelIndex() {
        return (inPopup ? tasksModel.makeModelIndex(groupDialog.visualParent.itemIndex, index)
            : tasksModel.makeModelIndex(index));
    }

    function showContextMenu(args) {
        toolTipArea.hideImmediately();
        contextMenu = tasks.createContextMenu(task, modelIndex(), args);
        if (contextMenu && contextMenu.show) {
            contextMenu.show();
        }
    }

    function updateAudioStreams(args) {
        if (args) {
            // When the task just appeared (e.g. virtual desktop switch), show the audio indicator
            // right away. Only when audio streams change during the lifetime of this task, delay
            // showing that to avoid distraction.
            delayAudioStreamIndicator = !!args.delay;
        }

        var pa = pulseAudio.item;
        if (!pa) {
            task.audioStreams = [];
            return;
        }

        var streams = pa.streamsForAppId(task.appId);
        if (!streams.length) {
            streams = pa.streamsForPid(task.pid);
            if (streams.length) {
                pa.registerPidMatch(task.appName);
            } else {
                // We only want to fall back to appName matching if we never managed to map
                // a PID to an audio stream window. Otherwise if you have two instances of
                // an application, one playing and the other not, it will look up appName
                // for the non-playing instance and erroneously show an indicator on both.
                if (!pa.hasPidMatch(task.appName)) {
                    streams = pa.streamsForAppName(task.appName);
                }
            }
        }

        task.audioStreams = streams;
    }

    function toggleMuted() {
        if (muted) {
            task.audioStreams.forEach(function (item) { item.unmute(); });
        } else {
            task.audioStreams.forEach(function (item) { item.mute(); });
        }
    }

    Connections {
        target: pulseAudio.item
        ignoreUnknownSignals: true // Plasma-PA might not be available
        function onStreamsChanged() {
            task.updateAudioStreams({delay: true})
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        enabled: task.visible
        hoverEnabled: false
        preventStealing: true
        propagateComposedEvents: false
        z: 1000

        onPressed: function(mouse) {
            mouse.accepted = true;
            task.forceActiveFocus();

            if (model.IsLauncher === true) {
                task.showContextMenu({showAllPlaces: true});
            } else {
                task.showContextMenu();
            }
        }
    }

    Component {
        id: taskInitComponent

        Timer {
            id: timer

            interval: Kirigami.Units.longDuration
            repeat: false

            onTriggered: {
                parent.hoverEnabled = true;

                if (parent.isWindow) {
                    tasksModel.requestPublishDelegateGeometry(parent.modelIndex(),
                        backend.globalRect(parent), parent);
                }

                timer.destroy();
            }

            Component.onCompleted: timer.start()
        }
    }

    KSvg.FrameSvgItem {
        id: frame
        Kirigami.ImageColors {
            id: imageColors
            source: effectiveIconSource
        }
        property color dominantColor: imageColors.dominant
        property color indicatorColor: Kirigami.ColorUtils.tintWithAlpha(frame.dominantColor, tintColor, .38)
        anchors {
            fill: parent

            topMargin: (!tasks.vertical && taskList.rows > 1) ? LayoutManager.iconMargin : 0
            bottomMargin: (!tasks.vertical && taskList.rows > 1) ? LayoutManager.iconMargin : 0
            leftMargin: ((inPopup || tasks.vertical) && taskList.columns > 1) ? LayoutManager.iconMargin : 0
            rightMargin: ((inPopup || tasks.vertical) && taskList.columns > 1) ? LayoutManager.iconMargin : 0           
        }
        imagePath: plasmoid.configuration.disableButtonSvg ? "" : "widgets/tasks"
        enabledBorders: plasmoid.configuration.useBorders ? (KSvg.FrameSvg.AllBorders & ~tasks.plasmaDecorationIndicatorBorder) : 0
        property bool isHovered: task.highlighted && plasmoid.configuration.taskHoverEffect
        property string basePrefix: "normal"
        prefix: isHovered ? TaskTools.taskPrefixHovered(basePrefix) : TaskTools.taskPrefix(basePrefix)
        visible: plasmoid.configuration.buttonColorize ? false : true
        onIsHoveredChanged: {
            console.log("[fancytasks_rld][Task] frame.isHovered changed:", frame.isHovered, "task.highlighted:", highlighted, "plasmoid.location:", plasmoid.location);
        }
    }

    ColorOverlay {
        id: colorOverride
        anchors.fill: frame
        source: frame
        color: plasmoid.configuration.buttonColorizeDominant ?
                frame.indicatorColor :
                plasmoid.configuration.buttonColorizeCustom
        visible: plasmoid.configuration.buttonColorize ? true : false
    }

    Flow {
        id: indicator
        visible: task.customIndicatorsEnabled
        flow: Flow.LeftToRight
        spacing: Kirigami.Units.smallSpacing
        clip: true
        readonly property int dotDiameter: task.isDots
            ? Math.max(plasmoid.configuration.indicatorSize, Math.round(Kirigami.Units.smallSpacing * 1.5))
            : Math.max(plasmoid.configuration.indicatorSize, plasmoid.configuration.indicatorLength)
        readonly property int effectiveThickness: task.isDots ? dotDiameter : plasmoid.configuration.indicatorSize
        readonly property int extraBottomSeparation: Math.max(4, Math.round(Kirigami.Units.smallSpacing))
        Repeater {

            model: {
                
                if(!task.customIndicatorsEnabled)
                return 0;
                if(task.childCount < plasmoid.configuration.indicatorMinLimit)
                return 0;
                if(task.isSubTask)//Target only the main task items.
                return 0;
                if(task.state === 'launcher') {
                    return 0;
                }
                return Math.min((task.childCount === 0) ? 1 : task.childCount, maxStates);
            }
            readonly property int maxStates: plasmoid.configuration.indicatorMaxLimit

            Rectangle{
                id: stateRect
                Behavior on height { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                Behavior on width { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                Behavior on color { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                Behavior on radius { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                readonly property color decoColor: frame.indicatorColor
                readonly property int maxStates: plasmoid.configuration.indicatorMaxLimit
                readonly property bool isFirst: index === 0
                readonly property int adjust: plasmoid.configuration.indicatorShrink
                readonly property int indicatorLength: plasmoid.configuration.indicatorLength
                readonly property int spacing: Kirigami.Units.smallSpacing
                readonly property int dotDiameter: indicator.dotDiameter
                readonly property bool isVertical: {
                    if(plasmoid.formFactor === PlasmaCore.Types.Vertical && !plasmoid.configuration.indicatorOverride)
                    return true;
                    if(plasmoid.formFactor == PlasmaCore.Types.Floating && plasmoid.configuration.indicatorOverride && (plasmoid.configuration.indicatorLocation === 1 || plasmoid.configuration.indicatorLocation === 2))
                    return  true;
                    if(plasmoid.configuration.indicatorOverride && (plasmoid.configuration.indicatorLocation === 1 || plasmoid.configuration.indicatorLocation === 2))
                    return  true;
                    else{
                        return false;
                    }
                }
                readonly property var computedVar: {
                    var height;
                    var width;
                    var colorCalc;
                    var colorEval = '#FFFFFF';
                    var parentSize = !isVertical ? frame.width : frame.height;
                    var indicatorComputedSize;
                    var adjustment = isFirst ? adjust : 0
                    var visibleStates = Math.min((task.childCount === 0) ? 1 : task.childCount, maxStates)
                    var parentSpacingAdjust = task.childCount >= 1 && maxStates >= 2 ? (spacing * 2.5) : 0 //Spacing fix for multiple items
                    if(plasmoid.configuration.indicatorDominantColor){
                        colorEval = decoColor
                    }
                    if(plasmoid.configuration.indicatorAccentColor){
                        colorEval = Kirigami.Theme.highlightColor
                    }
                    else if(!plasmoid.configuration.indicatorDominantColor && !plasmoid.configuration.indicatorAccentColor){
                        colorEval = plasmoid.configuration.indicatorCustomColor
                    }
                    if(isFirst){//compute the size
                        var growFactor = plasmoid.configuration.indicatorGrowFactor / 100
                        if(plasmoid.configuration.indicatorGrow && task.state === "minimized") {
                            var mainSize = indicatorLength * growFactor;
                        }
                        else{
                            var mainSize = (parentSize + parentSpacingAdjust);
                        }
                        switch(plasmoid.configuration.indicatorStyle){
                            case 0:
                            indicatorComputedSize = mainSize - (Math.min(task.childCount, maxStates === 1 ? 0 : maxStates)  * (spacing + indicatorLength)) - adjust
                            break
                            case 1:
                            indicatorComputedSize = (mainSize - adjust - (Math.max(0, visibleStates - 1) * spacing)) / visibleStates
                            break
                            case 2:
                            indicatorComputedSize = (plasmoid.configuration.indicatorGrow && task.state !== "minimized" ? indicatorLength * growFactor : indicatorLength) - adjustment
                            break
                            case 3:
                            indicatorComputedSize = plasmoid.configuration.indicatorGrow && task.state !== "minimized"
                                ? plasmoid.configuration.indicatorSize * growFactor
                                : plasmoid.configuration.indicatorSize
                            break
                            default:
                            break
                        }
                    }
                    else {
                        if (task.isDots) {
                            indicatorComputedSize = plasmoid.configuration.indicatorSize
                        } else if (plasmoid.configuration.indicatorStyle === 1) {
                            indicatorComputedSize = (parentSize - (Math.max(0, visibleStates - 1) * spacing)) / visibleStates
                        } else {
                            indicatorComputedSize = indicatorLength
                        }
                    }
                    indicatorComputedSize = Math.max(1, indicatorComputedSize)
                    if(task.isDots) {
                        indicatorComputedSize = Math.max(indicatorComputedSize, dotDiameter)
                    }
                    if(!isVertical){
                        width = indicatorComputedSize;
                        height = task.isDots ? indicatorComputedSize : plasmoid.configuration.indicatorSize
                    }
                    else{
                        width = task.isDots ? indicatorComputedSize : plasmoid.configuration.indicatorSize
                        height = indicatorComputedSize
                    }
                    if(plasmoid.configuration.indicatorDesaturate && task.state === "minimizedNormal") {
                        var colorHSL = hexToHSL(colorEval)
                        colorCalc = Qt.hsla(colorHSL.h, colorHSL.s*0.5, colorHSL.l*.8, 1)
                    }
                    else if(!isFirst && plasmoid.configuration.indicatorStyle ===  0 && task.state !== "minimizedNormal") {//Metro specific handling
                        colorCalc = Qt.darker(colorEval, 1.2) 
                    }
                    else {
                        colorCalc = colorEval
                    }
                    return {height: height, width: width, colorCalc: colorCalc}
                }
                width: computedVar.width
                height: computedVar.height
                color: plasmoid.configuration.indicatorStyle === 3 ? "transparent" : computedVar.colorCalc
                radius: (Math.min(width, height) / 2) * (plasmoid.configuration.indicatorRadius / 100)
                Rectangle {
                    id: dotShape
                    visible: plasmoid.configuration.indicatorStyle === 3
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    antialiasing: true
                    color: computedVar.colorCalc
                    radius: width / 2
                    border.width: Math.max(1, Math.round(width * 0.12))
                    border.color: Kirigami.ColorUtils.tintWithAlpha(computedVar.colorCalc, tintColor, 0.18)

                    Behavior on color { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                    Behavior on radius { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                }
                Rectangle{
                    Behavior on height { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                    Behavior on width { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                    Behavior on color { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                    Behavior on radius { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                    visible:  task.isWindow && task.smartLauncherItem && task.smartLauncherItem.progressVisible && isFirst && plasmoid.configuration.indicatorProgress
                    anchors{
                        top: plasmoid.configuration.indicatorStyle === 3 ? dotShape.top : parent.top
                        bottom: isVertical ? undefined : (plasmoid.configuration.indicatorStyle === 3 ? dotShape.bottom : parent.bottom)
                        left: plasmoid.configuration.indicatorStyle === 3 ? dotShape.left : parent.left
                        right: isVertical ? (plasmoid.configuration.indicatorStyle === 3 ? dotShape.right : parent.right) : undefined
                    }
                    readonly property var progress: {
                        if(task.smartLauncherItem && task.smartLauncherItem.progressVisible && task.smartLauncherItem.progress){
                            return task.smartLauncherItem.progress / 100
                        }
                        return 0
                    }
                    width: isVertical ? (plasmoid.configuration.indicatorStyle === 3 ? dotShape.width : parent.width) : (plasmoid.configuration.indicatorStyle === 3 ? dotShape.width : parent.width) * progress
                    height: isVertical ? (plasmoid.configuration.indicatorStyle === 3 ? dotShape.height : parent.height) * progress : (plasmoid.configuration.indicatorStyle === 3 ? dotShape.height : parent.height)
                    radius: plasmoid.configuration.indicatorStyle === 3 ? dotShape.radius : parent.radius
                    color: plasmoid.configuration.indicatorProgressColor
                }
            }   
        }
        
        states:[
            State {
                name: "bottom"
                when: (plasmoid.configuration.indicatorOverride && plasmoid.configuration.indicatorLocation === 0)
                    || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.BottomEdge && !plasmoid.configuration.indicatorReverse)
                    || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.TopEdge && plasmoid.configuration.indicatorReverse)
                    || (plasmoid.location === PlasmaCore.Types.Floating && plasmoid.configuration.indicatorLocation === 0)
                    || (plasmoid.location === PlasmaCore.Types.Floating && !plasmoid.configuration.indicatorOverride && !plasmoid.configuration.indicatorReverse)

                AnchorChanges {
                    target: indicator
                    anchors{ top:undefined; bottom:parent.bottom; left:undefined; right:undefined;
                        horizontalCenter:parent.horizontalCenter; verticalCenter:undefined}
                    }
                PropertyChanges {
                    target: indicator
                    width: undefined
                    height: indicator.effectiveThickness
                    anchors.topMargin: 0;
                    anchors.bottomMargin: plasmoid.configuration.indicatorEdgeOffset - indicator.extraBottomSeparation;
                    anchors.leftMargin: 0;
                    anchors.rightMargin: 0;
                }
            },
            State {
                name: "left"
                when: (plasmoid.configuration.indicatorOverride && plasmoid.configuration.indicatorLocation === 1)
                    || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.LeftEdge && !plasmoid.configuration.indicatorReverse)
                    || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.RightEdge && plasmoid.configuration.indicatorReverse)
                    || (plasmoid.location === PlasmaCore.Types.Floating && plasmoid.configuration.indicatorLocation === 1 && plasmoid.configuration.indicatorOverride)

                AnchorChanges {
                    target: indicator
                    anchors{ top:undefined; bottom:undefined; left:parent.left; right:undefined;
                        horizontalCenter:undefined; verticalCenter:parent.verticalCenter}
                }
                PropertyChanges {
                    target: indicator
                    height: undefined
                    width: indicator.effectiveThickness
                    anchors.topMargin: 0;
                    anchors.bottomMargin: 0;
                    anchors.leftMargin: plasmoid.configuration.indicatorEdgeOffset;
                    anchors.rightMargin: 0;
                }
            },
            State {
                name: "right"
                when: (plasmoid.configuration.indicatorOverride && plasmoid.configuration.indicatorLocation === 2)
                    || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.RightEdge && !plasmoid.configuration.indicatorReverse)
                    || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.LeftEdge && plasmoid.configuration.indicatorReverse)
                    || (plasmoid.location === PlasmaCore.Types.Floating && plasmoid.configuration.indicatorLocation === 2 && plasmoid.configuration.indicatorOverride)

                AnchorChanges {
                    target: indicator
                    anchors{ top:undefined; bottom:undefined; left:undefined; right:parent.right;
                        horizontalCenter:undefined; verticalCenter:parent.verticalCenter}
                }
                PropertyChanges {
                    target: indicator
                    height: undefined
                    width: indicator.effectiveThickness
                    anchors.topMargin: 0;
                    anchors.bottomMargin: 0;
                    anchors.leftMargin: 0;
                    anchors.rightMargin: plasmoid.configuration.indicatorEdgeOffset;
                }
            },
            State {
                name: "top"
                when: (plasmoid.configuration.indicatorOverride && plasmoid.configuration.indicatorLocation === 3)
                    || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.TopEdge && !plasmoid.configuration.indicatorReverse)
                    || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.BottomEdge && plasmoid.configuration.indicatorReverse)
                    || (plasmoid.location === PlasmaCore.Types.Floating && plasmoid.configuration.indicatorLocation === 3 && plasmoid.configuration.indicatorOverride)
                    || (plasmoid.location === PlasmaCore.Types.Floating && plasmoid.configuration.indicatorReverse && !plasmoid.configuration.indicatorOverride)

                AnchorChanges {
                    target: indicator
                    anchors{ top:parent.top; bottom:undefined; left:undefined; right:undefined;
                        horizontalCenter:parent.horizontalCenter; verticalCenter:undefined}
                }
                PropertyChanges {
                    target: indicator
                    width: undefined
                    height: indicator.effectiveThickness
                    anchors.topMargin: plasmoid.configuration.indicatorEdgeOffset;
                    anchors.bottomMargin: 0;
                    anchors.leftMargin: 0;
                    anchors.rightMargin: 0;
                }
            }
        ]
    }

    PlasmaCore.ToolTipArea {
        id: toolTipArea

        anchors.fill: parent
        location: plasmoid.location

        enabled: plasmoid.configuration.showToolTips
            && !inPopup
            && !tasks.groupDialog
            && (tasks.toolTipOpenedByClick === task || tasks.toolTipOpenedByClick === null)
        interactive: model.IsWindow === true || mainItem.hasPlayer

        // when the mouse leaves the tooltip area, a timer to hide is set for (timeout / 20) ms
        // see plasma-framework/src/declarativeimports/core/tooltipdialog.cpp function dismiss()
        // to compensate for that we multiply by 20 here, to get an effective leave timeout of 2s.
        timeout: (tasks.toolTipOpenedByClick === task) ? 2000*20 : 4000

        mainItem: (model.IsWindow === true) ? openWindowToolTipDelegate : pinnedAppToolTipDelegate

        onToolTipVisibleChanged: {
            if (!toolTipArea.toolTipVisible) {
                tasks.toolTipOpenedByClick = null;
                backend.cancelHighlightWindows();
            }
        }

        onContainsMouseChanged: if (containsMouse) {
            updateMainItemBindings();
        }

        // Will also be called in activateTaskAtIndex(index)
        function updateMainItemBindings() {
            if (tasks.toolTipOpenedByClick !== null && tasks.toolTipOpenedByClick !== task) {
                return;
            }

            mainItem.parentTask = task;
            mainItem.rootIndex = tasksModel.makeModelIndex(itemIndex, -1);

            mainItem.appName = Qt.binding(() => model.AppName);
            mainItem.pidParent = Qt.binding(() => model.AppPid !== undefined ? model.AppPid : 0);
            mainItem.windows = Qt.binding(() => model.WinIdList);
            mainItem.isGroup = Qt.binding(() => model.IsGroupParent === true);
            mainItem.icon = Qt.binding(() => effectiveIconSource);
            mainItem.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
            mainItem.isLauncher = Qt.binding(() => model.IsLauncher === true);
            mainItem.isMinimizedParent = Qt.binding(() => model.IsMinimized === true);
            mainItem.displayParent = Qt.binding(() => model.display);
            mainItem.genericName = Qt.binding(() => model.GenericName);
            mainItem.virtualDesktopParent = Qt.binding(() =>
                (model.VirtualDesktops !== undefined && model.VirtualDesktops.length > 0) ? model.VirtualDesktops : [0]);
            mainItem.isOnAllVirtualDesktopsParent = Qt.binding(() => model.IsOnAllVirtualDesktops === true);
            mainItem.activitiesParent = Qt.binding(() => model.Activities);

            mainItem.smartLauncherCountVisible = Qt.binding(() => task.effectiveBadgeVisible);
            mainItem.smartLauncherCount = Qt.binding(() => task.effectiveBadgeCount);
        }
    }




    Loader {
        anchors.fill: frame
        asynchronous: true
        source: "TaskProgressOverlay.qml"
        active: task.isWindow && task.smartLauncherItem && task.smartLauncherItem.progressVisible && !plasmoid.configuration.indicatorProgress
    }

    Item {
        id: iconBox

        anchors {
            left: parent.left
            leftMargin: adjustMargin(true, parent.width, taskFrame.margins.left)
            top: parent.top
            topMargin: adjustMargin(false, parent.height, taskFrame.margins.top)
        }

        width: {
            let isWider = parent.width > parent.height
            if(iconsOnly){
                return isWider ? height : parent.width;
            }
            if(!iconsOnly && plasmoid.configuration.iconSizeOverride){
                return plasmoid.configuration.iconSizePx
            }
            return height * (plasmoid.configuration.iconScale / 100)
        }
        height: (parent.height - adjustMargin(false, parent.height, taskFrame.margins.top)
            - adjustMargin(false, parent.height, taskFrame.margins.bottom))
        function adjustMargin(vert, size, margin) {
            if (!size) {
                return margin;
            }

            var margins = vert ? LayoutManager.horizontalMargins() : LayoutManager.verticalMargins();

            if ((size - margins) < Kirigami.Units.iconSizes.small) {
                return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
            }

            return margin;

        }

        //width: inPopup ? PlasmaCore.Units.iconSizes.small : Math.min(height, parent.width - LayoutManager.horizontalMargins())

        Item {
            id: icon
            anchors.centerIn: parent
            // Shift the icon down slightly to compensate for the drop shadow's downward visual
            // weight, which otherwise makes the icon appear to float above its geometric centre.
            readonly property int shadowVerticalShift: {
                if (!plasmoid.configuration.floatingIconShadow) return 0;
                switch (task.iconShadowType) {
                case 0: return 1;
                case 1: return 2;
                default: return 0;
                }
            }
            // Keep a small gap so a large icon does not visually collide with the indicator
            // without changing the preview container geometry.  The shadow shift is added here
            // so the icon can move down without visually touching the indicator.
            readonly property int indicatorGap: indicator.visible
                ? Math.max(2, Math.round(Kirigami.Units.smallSpacing / 2)) + shadowVerticalShift
                : 0
            readonly property int leftIndicatorReserve: indicator.visible && indicator.state === "left"
                ? indicator.effectiveThickness + plasmoid.configuration.indicatorEdgeOffset + indicatorGap
                : 0
            readonly property int rightIndicatorReserve: indicator.visible && indicator.state === "right"
                ? indicator.effectiveThickness + plasmoid.configuration.indicatorEdgeOffset + indicatorGap
                : 0
            readonly property int topIndicatorReserve: indicator.visible && indicator.state === "top"
                ? indicator.effectiveThickness + plasmoid.configuration.indicatorEdgeOffset + indicatorGap
                : 0
            readonly property int bottomIndicatorReserve: indicator.visible && indicator.state === "bottom"
                ? indicator.effectiveThickness + plasmoid.configuration.indicatorEdgeOffset + indicatorGap
                : 0
            readonly property int baseAvailableWidth: Math.max(1, parent.width - leftIndicatorReserve - rightIndicatorReserve)
            readonly property int baseAvailableHeight: Math.max(1, parent.height - topIndicatorReserve - bottomIndicatorReserve)
            readonly property int framePadding: task.showStaticIconFrame
                ? Math.max(8, Math.round(Math.min(baseAvailableWidth, baseAvailableHeight) * 0.18))
                : 0
            readonly property int framePaddingHalf: Math.round(framePadding / 2)
            anchors.horizontalCenterOffset: Math.round((leftIndicatorReserve - rightIndicatorReserve) / 2)
            anchors.verticalCenterOffset: Math.round((topIndicatorReserve - bottomIndicatorReserve) / 2) + shadowVerticalShift
            readonly property bool groupedFrameStackVisible: task.showStaticIconFrame
                && model.IsGroupParent === true
            readonly property real groupedFrameStackOffset: Math.max(3, Math.round(Math.min(width, height) * 0.13))

            function groupedFrameOffset(axis, depth) {
                const offset = groupedFrameStackOffset * depth;

                if (axis === "x") {
                    switch (plasmoid.location) {
                    case PlasmaCore.Types.LeftEdge:
                        return offset;
                    case PlasmaCore.Types.RightEdge:
                        return -offset;
                    default:
                        return -Math.round(offset * 0.72);
                    }
                }

                switch (plasmoid.location) {
                case PlasmaCore.Types.TopEdge:
                    return offset;
                case PlasmaCore.Types.BottomEdge:
                    return -offset;
                default:
                    return -Math.round(offset * 0.72);
                }
            }

            width: {
                const availableWidth = Math.max(1, baseAvailableWidth - framePadding)
                const availableHeight = Math.max(1, baseAvailableHeight - framePadding)
                let isWider = availableWidth > availableHeight
                if(iconsOnly && !plasmoid.configuration.iconSizeOverride){
                    return isWider ? availableHeight * (plasmoid.configuration.iconScale / 100) : availableWidth * (plasmoid.configuration.iconScale / 100)
                }
                if(iconsOnly && plasmoid.configuration.iconSizeOverride){
                    return plasmoid.configuration.iconSizePx
                }
                return Math.max(1, availableWidth)
            }
            height: width

            opacity: minimizedPreview.showPreview ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

            Repeater {
                model: icon.groupedFrameStackVisible ? 1 : 0

                delegate: Rectangle {
                    readonly property int stackDepth: index + 1

                    x: iconFrameOverlay.x + icon.groupedFrameOffset("x", stackDepth)
                    y: iconFrameOverlay.y + icon.groupedFrameOffset("y", stackDepth)
                    width: iconFrameOverlay.width
                    height: iconFrameOverlay.height
                    radius: iconFrameOverlay.radius
                    scale: stackDepth === 1 ? 0.98 : 0.95
                    color: task.iconFrameFillColor(stackDepth === 1 ? 0.92 : 0.72)
                    border.width: iconFrameOverlay.border.width
                    border.color: task.iconFrameBorderColor(stackDepth === 1 ? 0.96 : 0.82)
                    opacity: task.showStaticIconFrame ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                }
            }

            Rectangle {
                id: iconFrameOverlay
                // Build the frame from the icon's actual box so the icon stays centred inside it
                // and the added indicator reserve expands outward instead of shifting the frame.
                x: -icon.leftIndicatorReserve - icon.framePaddingHalf
                y: -icon.topIndicatorReserve - icon.framePaddingHalf - icon.shadowVerticalShift
                width: icon.width + icon.leftIndicatorReserve + icon.rightIndicatorReserve + icon.framePadding
                height: icon.height + icon.topIndicatorReserve + icon.bottomIndicatorReserve + icon.framePadding
                radius: Math.round(Math.min(width, height) * 0.28)
                color: task.iconFrameFillColor()
                border.width: task.darkPanel
                    ? Math.max(2, Math.round(Kirigami.Units.devicePixelRatio * 1.5))
                    : Math.max(2, Math.round(Kirigami.Units.devicePixelRatio * 1.25))
                border.color: task.iconFrameBorderColor()
                opacity: task.showStaticIconFrame ? 1 : 0
                scale: task.iconFrameHovered ? 1 : 0.97
                visible: opacity > 0

                RectangularGlow {
                    anchors.fill: parent
                    glowRadius: task.darkPanel ? Math.max(10, Math.round(parent.width * 0.12)) : Math.max(8, Math.round(parent.width * 0.10))
                    spread: task.darkPanel ? 0.22 : 0.18
                    cornerRadius: iconFrameOverlay.radius + glowRadius
                    color: task.iconFrameGlowColor()
                    visible: task.showStaticIconFrame
                }

                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            }

            transform: [
                Translate {
                    id: hoverTranslate
                    x: task.hoverOffsetForItem(icon, "x")
                    Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    y: task.hoverOffsetForItem(icon, "y")
                },
                Scale {
                    id: hoverScale
                    origin.x: icon.width / 2
                    origin.y: icon.height / 2
                    xScale: task.hoverScaleForItem(icon)
                    yScale: task.hoverScaleForItem(icon)
                    Behavior on xScale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    Behavior on yScale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                }
            ]

            Item {
                id: iconVisual
                anchors.centerIn: parent
                readonly property int renderBaseSize: 128
                width: renderBaseSize
                height: renderBaseSize
                scale: Math.max(icon.width, icon.height) / renderBaseSize

                DropShadow {
                    anchors.fill: iconImage
                    visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 0 && icon.opacity > 0
                    cached: true
                    transparentBorder: true
                    horizontalOffset: Math.max(1, Math.round(iconImage.width * 0.05))
                    verticalOffset: Math.max(1, Math.round(iconImage.height * 0.06))
                    radius: Math.max(4, Math.round(iconImage.height * 0.16))
                    samples: Math.max(9, 1 + (radius * 2))
                    color: task.iconShadowColor
                    source: iconImage
                }

                DropShadow {
                    anchors.fill: iconImage
                    visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 1 && icon.opacity > 0
                    cached: true
                    transparentBorder: true
                    horizontalOffset: Math.max(1, Math.round(iconImage.width * 0.03))
                    verticalOffset: Math.max(1, Math.round(iconImage.height * 0.03))
                    radius: Math.max(3, Math.round(iconImage.height * 0.08))
                    samples: Math.max(9, 1 + (radius * 2))
                    color: Qt.rgba(task.iconShadowColor.r, task.iconShadowColor.g, task.iconShadowColor.b, Math.min(1, task.iconShadowColor.a * 0.8))
                    source: iconImage
                }

                DropShadow {
                    anchors.fill: iconImage
                    visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 1 && icon.opacity > 0
                    cached: true
                    transparentBorder: true
                    horizontalOffset: Math.max(2, Math.round(iconImage.width * 0.07))
                    verticalOffset: Math.max(2, Math.round(iconImage.height * 0.12))
                    radius: Math.max(8, Math.round(iconImage.height * 0.24))
                    samples: Math.max(17, 1 + (radius * 2))
                    color: Qt.rgba(task.iconShadowColor.r, task.iconShadowColor.g, task.iconShadowColor.b, Math.min(1, task.iconShadowColor.a * 0.45))
                    source: iconImage
                }

                Glow {
                    anchors.fill: iconImage
                    visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 2 && icon.opacity > 0
                    cached: true
                    transparentBorder: true
                    radius: Math.max(6, Math.round(iconImage.height * 0.18))
                    samples: Math.max(13, 1 + (radius * 2))
                    spread: 0.18
                    color: Qt.rgba(task.iconShadowColor.r, task.iconShadowColor.g, task.iconShadowColor.b, Math.min(1, task.iconShadowColor.a * 1.1))
                    source: iconImage
                }

                Kirigami.Icon {
                    id: iconImage
                    anchors.fill: parent
                    source: effectiveIconSource
                }
            }

            Item {
                id: directBadgeOverlay
                visible: task.effectiveBadgeVisible
                z: 10000
                width: badgeBubble.width
                height: badgeBubble.height
                anchors.right: parent.right
                anchors.top: parent.top

                Rectangle {
                    id: badgeBubble
                    readonly property int minimumSize: Math.max(Kirigami.Units.gridUnit, Kirigami.Units.iconSizes.small / 2)
                    width: Math.max(minimumSize, Math.round(icon.width * 0.34))
                    height: width
                    radius: width / 2
                    color: "#ff1f1f"
                    border.color: "#ffffff"
                    border.width: Math.max(1, Math.round(Kirigami.Units.devicePixelRatio))

                    Text {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: Math.max(Kirigami.Theme.smallFont.pixelSize, Math.round(parent.height * 0.5))
                        text: {
                            const count = task.effectiveBadgeCount;
                            return count > 99 ? "99+" : count.toString();
                        }
                    }
                }
            }

            // Move Behaviors into the transform components to avoid invalid external references
        }

        // Minimized window preview: shows a cached snapshot of the window
        // content instead of the app icon when the window is minimized.
        // Uses PipeWire screencasting to capture the last visible frame on Wayland.
        Item {
            id: minimizedPreview
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: icon.anchors.horizontalCenterOffset
            anchors.verticalCenterOffset: icon.anchors.verticalCenterOffset
            width: icon.width
            height: icon.height

            readonly property bool featureActive: plasmoid.configuration.minimizedWindowPreview
                                                  && task.isWindow
                                                  && model.IsGroupParent !== true

            readonly property string resolvedWinUuid: {
                if (!featureActive) return "";
                if (!model.WinIdList || model.WinIdList.length === 0) return "";
                let wid = model.WinIdList[0];
                return (typeof wid === "string" && wid.length > 0) ? wid : "";
            }

            readonly property bool showPreview: featureActive
                                                && model.IsMinimized === true
                                                && resolvedWinUuid.length > 0
            readonly property real previewInset: Math.max(2, Math.round(Math.min(width, height) * 0.08))
            readonly property real previewExtent: Math.max(0, Math.min(width, height) - (previewInset * 2))
            readonly property real badgeSize: Math.min(previewExtent * 0.36, Kirigami.Units.iconSizes.smallMedium)
            readonly property real badgePadding: Math.max(2, Math.round(badgeSize * 0.16))
            property double lastHeartbeat: 0

            function requestCacheRefresh() {
                if (!featureActive || resolvedWinUuid.length === 0) {
                    return;
                }

                refreshTimer.restart();
            }

            onShowPreviewChanged: {
                if (showPreview) {
                    lastHeartbeat = Date.now();
                    requestCacheRefresh();
                } else {
                    lastHeartbeat = 0;
                    refreshTimer.stop();
                }
            }

            opacity: showPreview ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

            Rectangle {
                id: previewFrameOverlay
                x: -icon.leftIndicatorReserve - icon.framePaddingHalf
                y: -icon.topIndicatorReserve - icon.framePaddingHalf - icon.shadowVerticalShift
                width: minimizedPreview.width + icon.leftIndicatorReserve + icon.rightIndicatorReserve + icon.framePadding
                height: minimizedPreview.height + icon.topIndicatorReserve + icon.bottomIndicatorReserve + icon.framePadding
                radius: Math.round(Math.min(width, height) * 0.28)
                color: task.iconFrameFillColor()
                border.width: task.darkPanel
                    ? Math.max(2, Math.round(Kirigami.Units.devicePixelRatio * 1.5))
                    : Math.max(2, Math.round(Kirigami.Units.devicePixelRatio * 1.25))
                border.color: task.iconFrameBorderColor()
                opacity: task.showStaticIconFrame && minimizedPreview.showPreview ? 1 : 0
                scale: task.iconFrameHovered ? 1 : 0.97
                visible: opacity > 0
                z: -1

                RectangularGlow {
                    anchors.fill: parent
                    glowRadius: task.darkPanel ? Math.max(10, Math.round(parent.width * 0.12)) : Math.max(8, Math.round(parent.width * 0.10))
                    spread: task.darkPanel ? 0.22 : 0.18
                    cornerRadius: previewFrameOverlay.radius + glowRadius
                    color: task.iconFrameGlowColor()
                    visible: task.showStaticIconFrame && minimizedPreview.showPreview
                }

                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            }

            Timer {
                id: resumeWatchdog
                interval: 15000
                repeat: true
                running: minimizedPreview.showPreview

                onTriggered: {
                    const now = Date.now();

                    if (minimizedPreview.lastHeartbeat > 0 && now - minimizedPreview.lastHeartbeat > interval * 2) {
                        minimizedPreview.requestCacheRefresh();
                    }

                    minimizedPreview.lastHeartbeat = now;
                }
            }

            Timer {
                id: refreshTimer
                interval: 1200
                repeat: false
            }

            Item {
                id: previewContent
                anchors.fill: parent
                anchors.margins: minimizedPreview.previewInset
                visible: minimizedPreview.showPreview

                transform: [
                    Translate {
                        x: task.hoverOffsetForItem(previewContent, "x")
                        y: task.hoverOffsetForItem(previewContent, "y")
                        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    },
                    Scale {
                        origin.x: width / 2
                        origin.y: height / 2
                        xScale: task.hoverScaleForItem(previewContent)
                        yScale: task.hoverScaleForItem(previewContent)
                        Behavior on xScale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                        Behavior on yScale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    }
                ]

                DropShadow {
                    anchors.fill: previewSurface
                    visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 0 && previewContent.opacity > 0
                    cached: true
                    transparentBorder: true
                    horizontalOffset: Math.max(1, Math.round(previewSurface.width * 0.05))
                    verticalOffset: Math.max(1, Math.round(previewSurface.height * 0.06))
                    radius: Math.max(4, Math.round(previewSurface.height * 0.16))
                    samples: Math.max(9, 1 + (radius * 2))
                    color: task.iconShadowColor
                    source: previewSurface
                }

                DropShadow {
                    anchors.fill: previewSurface
                    visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 1 && previewContent.opacity > 0
                    cached: true
                    transparentBorder: true
                    horizontalOffset: Math.max(1, Math.round(previewSurface.width * 0.03))
                    verticalOffset: Math.max(1, Math.round(previewSurface.height * 0.03))
                    radius: Math.max(3, Math.round(previewSurface.height * 0.08))
                    samples: Math.max(9, 1 + (radius * 2))
                    color: Qt.rgba(task.iconShadowColor.r, task.iconShadowColor.g, task.iconShadowColor.b, Math.min(1, task.iconShadowColor.a * 0.8))
                    source: previewSurface
                }

                DropShadow {
                    anchors.fill: previewSurface
                    visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 1 && previewContent.opacity > 0
                    cached: true
                    transparentBorder: true
                    horizontalOffset: Math.max(2, Math.round(previewSurface.width * 0.07))
                    verticalOffset: Math.max(2, Math.round(previewSurface.height * 0.12))
                    radius: Math.max(8, Math.round(previewSurface.height * 0.24))
                    samples: Math.max(17, 1 + (radius * 2))
                    color: Qt.rgba(task.iconShadowColor.r, task.iconShadowColor.g, task.iconShadowColor.b, Math.min(1, task.iconShadowColor.a * 0.45))
                    source: previewSurface
                }

                Glow {
                    anchors.fill: previewSurface
                    visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 2 && previewContent.opacity > 0
                    cached: true
                    transparentBorder: true
                    radius: Math.max(6, Math.round(previewSurface.height * 0.18))
                    samples: Math.max(13, 1 + (radius * 2))
                    spread: 0.18
                    color: Qt.rgba(task.iconShadowColor.r, task.iconShadowColor.g, task.iconShadowColor.b, Math.min(1, task.iconShadowColor.a * 1.1))
                    source: previewSurface
                }

                Item {
                    id: previewSurface
                    anchors.fill: parent

                    // Loaded from a separate QML file so that missing org.kde.pipewire
                    // doesn't cause an import error for the entire Task component.
                    Loader {
                        anchors.fill: parent
                        active: minimizedPreview.showPreview
                        visible: active
                        asynchronous: true
                        source: "TaskPipeWirePreview.qml"

                        // Expose context for TaskPipeWirePreview.qml
                        property string windowUuid: minimizedPreview.resolvedWinUuid
                        // Keep the PipeWire stream always live — no layer freeze.
                        // The stream delivers the last visible frame from KWin.
                        property bool isMinimized: false
                    }
                }
            }

            Item {
                id: previewBadge
                visible: minimizedPreview.showPreview
                z: 1
                width: 0
                height: 0
                anchors.horizontalCenter: previewContent.horizontalCenter
                anchors.bottom: previewContent.bottom
                anchors.bottomMargin: {
                    // Force re-evaluation when these change
                    var indVisible = indicator.visible
                    var indState = indicator.state
                    var indEnabled = task.customIndicatorsEnabled
                    if (indEnabled && indVisible && indState === "bottom") {
                        var previewBottomInTask = iconBox.y + minimizedPreview.y + previewContent.y + previewContent.height
                        var margin = previewBottomInTask + minimizedPreview.badgeSize / 2 - indicator.y + 1
                        return Math.max(0, Math.ceil(margin))
                    }
                    return 0
                }

                Item {
                    id: previewBadgeIcon
                    anchors.centerIn: parent
                    width: minimizedPreview.badgeSize
                    height: width
                    transform: [
                        Translate {
                            x: task.hoverOffsetForItem(previewBadgeIcon, "x")
                            y: task.hoverOffsetForItem(previewBadgeIcon, "y")
                            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                        },
                        Scale {
                            origin.x: width / 2
                            origin.y: height / 2
                            xScale: task.hoverScaleForItem(previewBadgeIcon)
                            yScale: task.hoverScaleForItem(previewBadgeIcon)
                            Behavior on xScale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                            Behavior on yScale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                        }
                    ]

                    DropShadow {
                        anchors.fill: previewBadgeImage
                        visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 0 && previewBadgeIcon.opacity > 0
                        cached: true
                        transparentBorder: true
                        horizontalOffset: Math.max(1, Math.round(previewBadgeImage.width * 0.05))
                        verticalOffset: Math.max(1, Math.round(previewBadgeImage.height * 0.06))
                        radius: Math.max(3, Math.round(previewBadgeImage.height * 0.16))
                        samples: Math.max(9, 1 + (radius * 2))
                        color: task.iconShadowColor
                        source: previewBadgeImage
                    }

                    DropShadow {
                        anchors.fill: previewBadgeImage
                        visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 1 && previewBadgeIcon.opacity > 0
                        cached: true
                        transparentBorder: true
                        horizontalOffset: Math.max(1, Math.round(previewBadgeImage.width * 0.03))
                        verticalOffset: Math.max(1, Math.round(previewBadgeImage.height * 0.03))
                        radius: Math.max(2, Math.round(previewBadgeImage.height * 0.08))
                        samples: Math.max(7, 1 + (radius * 2))
                        color: Qt.rgba(task.iconShadowColor.r, task.iconShadowColor.g, task.iconShadowColor.b, Math.min(1, task.iconShadowColor.a * 0.8))
                        source: previewBadgeImage
                    }

                    DropShadow {
                        anchors.fill: previewBadgeImage
                        visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 1 && previewBadgeIcon.opacity > 0
                        cached: true
                        transparentBorder: true
                        horizontalOffset: Math.max(1, Math.round(previewBadgeImage.width * 0.07))
                        verticalOffset: Math.max(1, Math.round(previewBadgeImage.height * 0.12))
                        radius: Math.max(5, Math.round(previewBadgeImage.height * 0.24))
                        samples: Math.max(11, 1 + (radius * 2))
                        color: Qt.rgba(task.iconShadowColor.r, task.iconShadowColor.g, task.iconShadowColor.b, Math.min(1, task.iconShadowColor.a * 0.45))
                        source: previewBadgeImage
                    }

                    Glow {
                        anchors.fill: previewBadgeImage
                        visible: plasmoid.configuration.floatingIconShadow && task.iconShadowType === 2 && previewBadgeIcon.opacity > 0
                        cached: true
                        transparentBorder: true
                        radius: Math.max(4, Math.round(previewBadgeImage.height * 0.18))
                        samples: Math.max(9, 1 + (radius * 2))
                        spread: 0.18
                        color: Qt.rgba(task.iconShadowColor.r, task.iconShadowColor.g, task.iconShadowColor.b, Math.min(1, task.iconShadowColor.a * 1.1))
                        source: previewBadgeImage
                    }

                    Item {
                        id: previewBadgeVisual
                        anchors.centerIn: parent
                        readonly property int renderBaseSize: 64
                        width: renderBaseSize
                        height: renderBaseSize
                        scale: Math.max(previewBadgeIcon.width, previewBadgeIcon.height) / renderBaseSize

                        Kirigami.Icon {
                            id: previewBadgeImage
                            anchors.fill: parent
                            source: effectiveIconSource
                        }
                    }
                }
            }
        }

        Loader {
            width: 0
            height: 0
            active: false
            visible: false
        }

        states: [
            // Using a state transition avoids a binding loop between label.visible and
            // the text label margin, which derives from the icon width.
            State {
                name: "standalone"
                when: !label.visible

                AnchorChanges {
                    target: iconBox
                    anchors.left: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                PropertyChanges {
                    target: iconBox
                    anchors.leftMargin: 0
                }
            }
        ]

        Loader {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            active: model.IsStartup === true
            sourceComponent: busyIndicator
        }

        Component {
            id: busyIndicator
            PlasmaComponents3.BusyIndicator {}
        }
    }

    Loader {
        id: audioStreamIconLoader

        readonly property bool shown: item && item.visible
        readonly property var indicatorScale: 1.2

        source: "AudioStream.qml"
        width: Math.min(Math.min(iconBox.width, iconBox.height) * 0.4, Kirigami.Units.iconSizes.smallMedium)
        height: width

        Binding {
            target: audioStreamIconLoader.item
            property: "dominantIconColor"
            value: frame.indicatorColor
        }

        anchors {
            right: frame.right
            top: frame.top
            rightMargin: taskFrame.margins.right
            topMargin: Math.round(taskFrame.margins.top * indicatorScale)
        }
    }

    PlasmaComponents3.Label {
        id: label

        visible: (inPopup || !iconsOnly && model.IsLauncher !== true
            && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= (tasks.defaultFontWidth * LayoutManager.minimumMColumns()))

        anchors {
            fill: parent
            leftMargin: taskFrame.margins.left + iconBox.width + LayoutManager.labelMargin
            topMargin: taskFrame.margins.top
            rightMargin: taskFrame.margins.right + (audioStreamIconLoader.shown ? (audioStreamIconLoader.width + LayoutManager.labelMargin) : 0)
            bottomMargin: taskFrame.margins.bottom
        }

        wrapMode: (maximumLineCount == 1) ? Text.NoWrap : Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: plasmoid.configuration.maxTextLines || undefined

        // use State to avoid unnecessary re-evaluation when the label is invisible
        states: State {
            name: "labelVisible"
            when: label.visible

            PropertyChanges {
                target: label
                text: model.display || ""
            }
        }
    }

    states: [
        State {
            name: "launcher"
            when: model.IsLauncher === true

            PropertyChanges {
                target: frame
                basePrefix: ""
            }
            PropertyChanges { 
                target: colorOverride
                visible: false
            }
        },
        State {
            name: "attention"
            when: model.IsDemandingAttention === true || (task.smartLauncherItem && task.smartLauncherItem.urgent)

            PropertyChanges {
                target: frame
                basePrefix: "attention"
                visible: (plasmoid.configuration.buttonColorize && !frame.isHovered) || !plasmoid.configuration.buttonColorize
            }
            PropertyChanges { 
                target: colorOverride
                visible: (plasmoid.configuration.buttonColorize && frame.isHovered)
            }
        },
        State {
            name: "minimizedNormal"
            when: model.IsMinimized === true && !frame.isHovered && !plasmoid.configuration.disableButtonInactiveSvg

            PropertyChanges {
                target: frame
                basePrefix: "minimized"
                visible: false
            }
            PropertyChanges { 
                target: colorOverride
                visible: (plasmoid.configuration.buttonColorize && plasmoid.configuration.buttonColorizeInactive) ? true : false
            }
            PropertyChanges{
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ? false : true
            }
        },
        State {
            name: "minimizedNodecoration"
            when: (model.IsMinimized === true && !frame.isHovered) && plasmoid.configuration.disableButtonInactiveSvg

            PropertyChanges {
                target: frame
                basePrefix: "minimized"
                visible: false
            }
            PropertyChanges { 
                target: colorOverride
                visible: plasmoid.configuration.disableButtonInactiveSvg ? false : true
            }
            PropertyChanges{
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ? false : true
            }
        },
        State {
            name: "active"
            when: model.IsActive === true

            PropertyChanges {
                target: frame
                basePrefix: "focus"
                visible: false
            }
            PropertyChanges { 
                target: colorOverride
                visible: plasmoid.configuration.buttonColorize ? true : false
            }
            PropertyChanges{
                target: indicator
                visible: task.customIndicatorsEnabled
            }
        },
        State {
            name: "inactiveNormal"
            when: model.IsActive === false && !frame.isHovered && !plasmoid.configuration.disableButtonInactiveSvg
            PropertyChanges { 
                target: colorOverride
                visible: plasmoid.configuration.buttonColorize && plasmoid.configuration.buttonColorizeInactive ? true : false
            }
            PropertyChanges { 
                target: frame
                visible: false
            }
            PropertyChanges{
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ? false : true
            }
        },
        State {
            name: "inactiveNoDecoration"
            when: (model.IsActive === false && !frame.isHovered) && plasmoid.configuration.disableButtonInactiveSvg
            PropertyChanges { 
                target: colorOverride
                visible: plasmoid.configuration.disableButtonInactiveSvg ? false : true
            }
            PropertyChanges { 
                target: frame
                visible: false
            }
            PropertyChanges{
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ? false : true
            }
        },
        State {
            name: "hover"
            when: frame.isHovered
                && !(model.IsDemandingAttention === true || (task.smartLauncherItem && task.smartLauncherItem.urgent))
            PropertyChanges { 
                target: colorOverride
                visible: plasmoid.configuration.buttonColorize ? true : false
            }
            PropertyChanges { 
                target: frame
                visible: false
            }
            PropertyChanges{
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ? false : true
            }
        }
    ]

    Component.onCompleted: {
        ensureSmartLauncherItem();
        if (model.IsActive === true) {
            scheduleActiveBadgeReset();
        }

        if (!inPopup && model.IsWindow === true) {
            if(plasmoid.configuration.groupIconEnabled){
                var component = Qt.createComponent("GroupExpanderOverlay.qml");
                component.createObject(iconBox);
            }
        }

        if (!inPopup && model.IsWindow !== true) {
            taskInitComponent.createObject(task);
        }

        updateAudioStreams({delay: false})

        // Pre-cache .desktop file for context menu jump list actions
        if (model.LauncherUrlWithoutIcon) {
            backend.cacheDesktopFile(model.LauncherUrlWithoutIcon);
        }
    }
}
