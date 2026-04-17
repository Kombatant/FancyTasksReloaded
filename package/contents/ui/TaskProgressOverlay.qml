/*
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15

import org.kde.ksvg as KSvg

import "code/tools.js" as TaskTools

Item {
    id: background

    Item {
        id: progress
        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
        }

        width: parent.width * (task.smartLauncherItem.progress / 100)
        clip: true

        KSvg.FrameSvgItem {
            enabledBorders: plasmoid.configuration.useBorders ? 1 | 2 | 4 | 8 : 0
            id: progressFrame
            width: background.width
            height: background.height
            imagePath: "widgets/tasks"
            prefix: TaskTools.taskPrefix("progress").concat(TaskTools.taskPrefix("hover"))
        }
    }
}
