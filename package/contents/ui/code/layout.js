/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

// @ts-nocheck

.import org.kde.plasma.core as PlasmaCore
.import org.kde.kirigami 2.19 as Kirigami

var iconMargin = 1;
var labelMargin = 1;

function refreshConstants() {
    if (tasks) {
        iconMargin = Math.round(tasks.smallSpacing / 4);
        labelMargin = tasks.smallSpacing;
    }
}

function horizontalMargins() {
    refreshConstants();
    const spacingAdjustment = Kirigami.Settings.tabletMode ? 3 : plasmoid.configuration.iconSpacing;
    const baseMargins = taskFrame.margins.left + taskFrame.margins.right;

    // Some Plasma themes expose zero horizontal SVG margins for task buttons,
    // which made the icon spacing setting a no-op. Fall back to a small
    // layout-derived margin so the setting still visibly changes icon gaps.
    return Math.max(baseMargins, Math.round(tasks.smallSpacing / 2)) * spacingAdjustment;
}

function verticalMargins() {
    refreshConstants();
    const spacingAdjustment = Kirigami.Settings.tabletMode ? 3 : plasmoid.configuration.iconSpacing;
    const baseMargins = taskFrame.margins.top + taskFrame.margins.bottom;

    return Math.max(baseMargins, Math.round(tasks.smallSpacing / 2)) * spacingAdjustment;
}

function adjustMargin(height, margin) {
    var available = height - verticalMargins();

    if (available < tasks.iconSizeSmall) {
        return Math.floor((margin * (tasks.iconSizeSmall / available)) / 3);
    }

    return margin;
}

function launcherLayoutTasks() {
    return Math.round(tasksModel.logicalLauncherCount / Math.floor(preferredMinWidth() / launcherWidth()));
}

function launcherLayoutWidthDiff() {
    return (launcherLayoutTasks() * taskWidth()) - (tasksModel.logicalLauncherCount * launcherWidth());
}

function logicalTaskCount() {
    var count = (tasksModel.count - tasksModel.logicalLauncherCount) + launcherLayoutTasks();

    return Math.max(tasksModel.count ? 1 : 0, count);
}

function maxStripes() {
    var length = tasks.vertical ? taskList.width : taskList.height;
    var minimum = tasks.vertical ? preferredMinWidth() : preferredMinHeight();

    return Math.min(plasmoid.configuration.maxStripes, Math.max(1, Math.floor(length / minimum)));
}

function tasksPerStripe() {
    if (plasmoid.configuration.forceStripes) {
        return Math.ceil(logicalTaskCount() / maxStripes());
    } else {
        var length = tasks.vertical ? taskList.height : taskList.width;
        var minimum = tasks.vertical ? preferredMinHeight() : preferredMinWidth();

        return Math.floor(length / minimum);
    }
}

function calculateStripes() {
    var stripes = plasmoid.configuration.forceStripes ? plasmoid.configuration.maxStripes : Math.min(plasmoid.configuration.maxStripes, Math.ceil(logicalTaskCount() / tasksPerStripe()));

    return Math.min(stripes, maxStripes());
}

function full() {
    return (maxStripes() == calculateStripes());
}

function optimumCapacity(width, height) {
    var length = tasks.vertical ? height : width;
    var maximum = tasks.vertical ? preferredMaxHeight() : preferredMaxWidth();

    if (!tasks.vertical) {
        //  Fit more tasks in this case, that is possible to cut text, before combining tasks.
        return Math.ceil(length / maximum) * maxStripes() + 1;
    }

    return Math.floor(length / maximum) * maxStripes();
}

function layoutWidth() {
    if (plasmoid.configuration.forceStripes && !tasks.vertical) {
        return Math.min(tasks.width - (tasksPerStripe() * plasmoid.configuration.taskSpacingSize), Math.max(preferredMaxWidth(), tasksPerStripe() * preferredMaxWidth()));
    } else {
        return tasks.width;
    }
}

function layoutHeight() {
    if (plasmoid.configuration.forceStripes && tasks.vertical) {
        return Math.min(tasks.height - (tasksPerStripe() * plasmoid.configuration.taskSpacingSize), Math.max(preferredMaxHeight(), tasksPerStripe() * preferredMaxHeight()));
    } else {
        return tasks.height;
    }
}

function preferredMinWidth() {
    var width = launcherBaseWidth();

    if (!tasks.vertical && !tasks.iconsOnly) {
      width +=
          (tasks.smallSpacing * 2) +
                    plasmoid.configuration.maxButtonLength;
    }

    return width;
}

function preferredMaxWidth() {
    if (tasks.iconsOnly) {
        if (tasks.vertical) {
            return tasks.width + verticalMargins();
        } else {
            return tasks.height + horizontalMargins();
        }
    }

    if (plasmoid.configuration.groupingStrategy != 0 && !plasmoid.configuration.groupPopups) {
        return preferredMinWidth();
    }

    return Math.floor(preferredMinWidth());
}

function preferredMinHeight() {
    // TODO FIXME UPSTREAM: Port to proper font metrics for descenders once we have access to them.
    return tasks.defaultFontHeight + 4;
}

function preferredMaxHeight() {
    if (tasks.vertical) {
      return verticalMargins() +
             Math.min(
                 // Do not allow the preferred icon size to exceed the width of
                 // the vertical task manager.
                 tasks.width,
                 tasks.iconsOnly ? tasks.width :
                    Math.max(
                        tasks.defaultFontHeight,
                        tasks.iconSizeMedium
                    )
             );
    } else {
      return verticalMargins() +
             Math.min(
                 tasks.iconSizeSmall * 3,
                 tasks.defaultFontHeight * 3);
    }
}

// Returns the number of 'm' characters whose joint width must be available in the task button label
// so that the button text is rendered at all.
function minimumMColumns() {
    return tasks.vertical ? 4 : 5;
}

function taskWidth() {
    if (tasks.vertical) {
        return Math.floor(taskList.width / calculateStripes());
    } else {
        if (full() && Math.max(1, logicalTaskCount()) > tasksPerStripe()) {
            return Math.floor(taskList.width / Math.ceil(logicalTaskCount() / maxStripes()));
        } else {
            return Math.min(preferredMaxWidth(), Math.floor(taskList.width / Math.min(logicalTaskCount(), tasksPerStripe())));
        }
    }
}

function taskHeight() {
    if (tasks.vertical) {
        if (full() && Math.max(1, logicalTaskCount()) > tasksPerStripe()) {
            return Math.floor(taskList.height / Math.ceil(logicalTaskCount() / maxStripes()));
        } else {
            return Math.min(preferredMaxHeight(), Math.floor(taskList.height / Math.min(logicalTaskCount(), tasksPerStripe())));
        }
    } else {
        return Math.floor(taskList.height / calculateStripes());
    }
}

function launcherWidth() {
    refreshConstants();
    var width = launcherBaseWidth();

    if (!tasks.iconsOnly) {
        width += labelMargin * 2;
    }

    return width;
}

function launcherBaseWidth() {
    var baseWidth = tasks.vertical ? preferredMinHeight() : Math.min(tasks.height, tasks.iconSizeSmall * 3);

    if (!tasks.iconsOnly) {
        baseWidth = Math.max(baseWidth, tasks.height);
    }

    var width = launcherInnerWidth(baseWidth) + horizontalMargins();

    if (!tasks.iconsOnly) {
        width = Math.max(width, launcherIconWidth(baseWidth) + horizontalMargins());
    }

    return width;
}

function maximumContextMenuTextWidth() {
    return tasks.defaultFontWidth * 28;
}

function launcherInnerWidth(baseWidth) {
    return Math.max(0, baseWidth
        - adjustMargin(baseWidth, taskFrame.margins.top)
        - adjustMargin(baseWidth, taskFrame.margins.bottom));
}

function launcherIconWidth(baseWidth) {
    const iconWidth = launcherInnerWidth(baseWidth);

    if (tasks.iconsOnly) {
        return iconWidth;
    }

    if (plasmoid.configuration.iconSizeOverride) {
        return plasmoid.configuration.iconSizePx;
    }

    return iconWidth * (plasmoid.configuration.iconScale / 100);
}

function canLayout(container) {
    return !!container
        && taskList.width > 0
        && taskList.height > 0
        && tasks.width > 0
        && tasks.height > 0;
}

function clampLayoutExtent(value) {
    return Math.max(1, Math.floor(value));
}

function layout(container) {
    if (!canLayout(container)) {
        return;
    }

    var item;
    var stripes = calculateStripes();
    var taskCount = tasksModel.count - tasksModel.logicalLauncherCount;
    var width = taskWidth();
    var adjustedWidth = width;
    var height = taskHeight();

    console.log("[fancytasks_rld][layout] layout() called; count=" + tasksModel.count
                + " launcherCount=" + tasksModel.logicalLauncherCount
                + " taskCount=" + taskCount + " stripes=" + stripes
                + " width=" + width + " height=" + height);

    if (!tasks.vertical && stripes == 1 && taskCount)
    {
        var shrink = ((tasksModel.count - tasksModel.logicalLauncherCount) * preferredMaxWidth())
            + (tasksModel.logicalLauncherCount * launcherWidth()) > taskList.width;
        width = Math.min(shrink ? width + Math.floor(launcherLayoutWidthDiff() / taskCount) : width,
            preferredMaxWidth());
    }

    width = clampLayoutExtent(width);
    height = clampLayoutExtent(height);

    for (var i = 0; i < container.count; ++i) {
        item = container.itemAt(i);

        if (!item) {
            continue;
        }

        adjustedWidth = width;

        if (!tasks.vertical && !tasks.iconsOnly && (tasks.effectiveSeparateLaunchers || stripes == 1)) {
            if (item.m.IsLauncher === true
                || (!tasks.effectiveSeparateLaunchers && item.m.IsStartup === true && item.m.HasLauncher === true)) {
                adjustedWidth = launcherWidth();
            } else if (stripes > 1 && i == tasksModel.logicalLauncherCount) {
                adjustedWidth += launcherLayoutWidthDiff();
            }
        }

        adjustedWidth = clampLayoutExtent(adjustedWidth);

        console.log("[fancytasks_rld][layout]   item[" + i + "] appName=" + (item.appName || "?")
                    + " IsLauncher=" + item.m.IsLauncher
                    + " IsWindow=" + item.m.IsWindow
                    + " w=" + adjustedWidth + " h=" + height);

        // Keep delegate slots stable while the icon itself animates. The
        // panel hover budget is handled separately at the container level.
        item.width = adjustedWidth;
        item.height = height;
        item.visible = true;
    }
}
