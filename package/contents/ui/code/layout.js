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

function effectiveIconSpacing() {
    if (Kirigami.Settings.tabletMode) {
        return 3;
    }

    if ((plasmoid.configuration.hoverEffectsEnabled || plasmoid.configuration.hoverBounce)
        && Number(plasmoid.configuration.hoverEffectMode || 0) === 1) {
        return 3;
    }

    return plasmoid.configuration.iconSpacing;
}

function horizontalMargins() {
    refreshConstants();
    const spacingAdjustment = effectiveIconSpacing();
    const baseMargins = taskFrame.margins.left + taskFrame.margins.right;

    // Some Plasma themes expose zero horizontal SVG margins for task buttons,
    // which made the icon spacing setting a no-op. Fall back to a small
    // layout-derived margin so the setting still visibly changes icon gaps.
    return Math.max(baseMargins, Math.round(tasks.smallSpacing / 2)) * spacingAdjustment;
}

function verticalMargins() {
    refreshConstants();
    const spacingAdjustment = effectiveIconSpacing();
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
    var logicalLaunchers = launcherLayoutTasks();
    var extraLauncherSpacing = Math.max(0,
        tasksModel.logicalLauncherCount - logicalLaunchers) * taskList.spacing;

    return (logicalLaunchers * taskWidth())
        - (tasksModel.logicalLauncherCount * launcherWidth())
        - extraLauncherSpacing;
}

function logicalTaskCount() {
    var count = (tasksModel.count - tasksModel.logicalLauncherCount) + launcherLayoutTasks();

    return Math.max(tasksModel.count ? 1 : 0, count);
}

function visibleTaskCount() {
    return Math.max(0, tasksModel.count);
}

function visibleSpacing(count) {
    return Math.max(0, count - 1) * taskList.spacing;
}

function horizontalLauncherCountForLayout(count) {
    if (tasks.iconsOnly) {
        return 0;
    }

    return Math.max(0, Math.min(tasksModel.logicalLauncherCount, count));
}

function forceFlowLayout() {
    return plasmoid.configuration.forceStripes || plasmoid.configuration.maxStripes <= 1;
}

function maxStripes() {
    var length = tasks.vertical ? taskList.width : taskList.height;
    var minimum = tasks.vertical ? preferredMinWidth() : preferredMinHeight();

    return Math.min(plasmoid.configuration.maxStripes,
        Math.max(1, Math.floor((length + taskList.spacing) / (minimum + taskList.spacing))));
}

function tasksPerStripe() {
    if (plasmoid.configuration.forceStripes) {
        return Math.ceil(logicalTaskCount() / maxStripes());
    } else {
        var length = tasks.vertical ? taskList.height : taskList.width;
        var minimum = tasks.vertical ? preferredMinHeight() : preferredMinWidth();

        return Math.max(1, Math.floor((length + taskList.spacing) / (minimum + taskList.spacing)));
    }
}

function calculateStripes() {
    var stripes = plasmoid.configuration.forceStripes ? plasmoid.configuration.maxStripes : Math.min(plasmoid.configuration.maxStripes, Math.ceil(logicalTaskCount() / tasksPerStripe()));

    return Math.min(stripes, maxStripes());
}

function full() {
    return (maxStripes() == calculateStripes());
}

function preferredLayoutWidth() {
    if (tasks.vertical) {
        return Kirigami.Units.gridUnit * 10 + tasks.hoverPanelThicknessExtra;
    }

    if (logicalTaskCount() === 0) {
        // Return a small non-zero value to make the panel account for the
        // change in size.
        return 0.01;
    }

    if (calculateStripes() === 1) {
        var count = visibleTaskCount();
        var launcherCount = horizontalLauncherCountForLayout(count);
        var windowCount = Math.max(0, count - launcherCount);

        return Math.max(0.01,
            (windowCount * preferredMaxWidth())
            + (launcherCount * launcherWidth())
            + visibleSpacing(count));
    }

    return (logicalTaskCount() * preferredMaxWidth()) / calculateStripes();
}

function preferredLayoutHeight() {
    if (!tasks.vertical) {
        return Kirigami.Units.gridUnit * 2 + tasks.hoverPanelThicknessExtra;
    }

    if (logicalTaskCount() === 0) {
        // Return a small non-zero value to make the panel account for the
        // change in size.
        return 0.01;
    }

    if (calculateStripes() === 1) {
        var count = visibleTaskCount();

        return Math.max(0.01,
            (count * preferredMaxHeight()) + visibleSpacing(count));
    }

    return (logicalTaskCount() * preferredMaxHeight()) / calculateStripes();
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
        return Math.min(tasks.width - (Math.max(0, tasksPerStripe() - 1) * plasmoid.configuration.taskSpacingSize),
            Math.max(preferredMaxWidth(), tasksPerStripe() * preferredMaxWidth()));
    } else {
        return tasks.width;
    }
}

function layoutHeight() {
    if (plasmoid.configuration.forceStripes && tasks.vertical) {
        return Math.min(tasks.height - (Math.max(0, tasksPerStripe() - 1) * plasmoid.configuration.taskSpacingSize),
            Math.max(preferredMaxHeight(), tasksPerStripe() * preferredMaxHeight()));
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
    var stripes = calculateStripes();

    if (tasks.vertical) {
        return Math.floor((taskList.width - ((stripes - 1) * taskList.spacing)) / stripes);
    } else {
        if (stripes === 1) {
            var count = Math.max(1, visibleTaskCount());
            var launcherCount = horizontalLauncherCountForLayout(count);
            var windowCount = Math.max(0, count - launcherCount);
            var spacing = visibleSpacing(count);

            if (windowCount > 0) {
                var launcherBudget = launcherCount * launcherWidth();
                var availableForWindows = taskList.width - spacing - launcherBudget;

                if (availableForWindows >= windowCount) {
                    return Math.min(preferredMaxWidth(),
                        Math.floor(availableForWindows / windowCount));
                }
            }

            return Math.min(preferredMaxWidth(),
                Math.floor((taskList.width - spacing) / count));
        }

        if (full() && Math.max(1, logicalTaskCount()) > tasksPerStripe()) {
            var perStripeCount = Math.ceil(logicalTaskCount() / maxStripes());
            return Math.floor((taskList.width - ((perStripeCount - 1) * taskList.spacing)) / perStripeCount);
        } else {
            var visibleCount = Math.max(1, Math.min(logicalTaskCount(), tasksPerStripe()));
            return Math.min(preferredMaxWidth(),
                Math.floor((taskList.width - ((visibleCount - 1) * taskList.spacing)) / visibleCount));
        }
    }
}

function taskHeight() {
    var stripes = calculateStripes();

    if (tasks.vertical) {
        if (full() && Math.max(1, logicalTaskCount()) > tasksPerStripe()) {
            var perStripeCount = Math.ceil(logicalTaskCount() / maxStripes());
            return Math.floor((taskList.height - ((perStripeCount - 1) * taskList.spacing)) / perStripeCount);
        } else {
            var visibleCount = Math.max(1, Math.min(logicalTaskCount(), tasksPerStripe()));
            return Math.min(preferredMaxHeight(),
                Math.floor((taskList.height - ((visibleCount - 1) * taskList.spacing)) / visibleCount));
        }
    } else {
        return Math.floor((taskList.height - ((stripes - 1) * taskList.spacing)) / stripes);
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

function shouldDisplayTaskItem(item) {
    if (!item || !item.m) {
        return false;
    }

    return item.m.IsWindow === true
        || item.m.IsLauncher === true
        || item.m.IsStartup === true;
}

function layout(container) {
    if (!canLayout(container)) {
        return;
    }

    var item;
    var stripes = calculateStripes();
    var width = clampLayoutExtent(taskWidth());
    var adjustedWidth = width;
    var height = clampLayoutExtent(taskHeight());
    var shrinkSingleStripeLaunchers = false;
    var singleStripeLauncherWidth = launcherWidth();

    if (!tasks.vertical && stripes == 1)
    {
        var visibleCount = visibleTaskCount();
        var launcherCount = horizontalLauncherCountForLayout(visibleCount);
        var spacing = visibleSpacing(visibleCount);

        shrinkSingleStripeLaunchers = launcherCount > 0
            && ((launcherCount * singleStripeLauncherWidth)
                + (Math.max(0, visibleCount - launcherCount) * width)
                + spacing > taskList.width);
    }

    singleStripeLauncherWidth = clampLayoutExtent(shrinkSingleStripeLaunchers
        ? width : singleStripeLauncherWidth);

    for (var i = 0; i < container.count; ++i) {
        item = container.itemAt(i);

        if (!item) {
            continue;
        }

        if (!shouldDisplayTaskItem(item)) {
            item.visible = false;
            item.width = 0;
            item.height = 0;
            continue;
        }

        adjustedWidth = width;

        if (!tasks.vertical && !tasks.iconsOnly && (tasks.effectiveSeparateLaunchers || stripes == 1)) {
            if (item.m.IsLauncher === true
                || (!tasks.effectiveSeparateLaunchers && item.m.IsStartup === true && item.m.HasLauncher === true)) {
                adjustedWidth = stripes == 1 ? singleStripeLauncherWidth : launcherWidth();
            } else if (stripes > 1 && i == tasksModel.logicalLauncherCount) {
                adjustedWidth += launcherLayoutWidthDiff();
            }
        }

        adjustedWidth = clampLayoutExtent(adjustedWidth);

        // Keep delegate slots stable while the icon itself animates. The
        // panel hover budget is handled separately at the container level.
        item.width = adjustedWidth;
        item.height = height;
        item.visible = true;
    }
}
