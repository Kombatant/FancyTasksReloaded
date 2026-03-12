/*
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15

import org.kde.kirigami 2.20 as Kirigami

Item {
    readonly property int iconWidthDelta: 0
    readonly property bool shiftBadgeDown: (plasmoid.configuration.iconOnly) && task.audioStreamIconLoaderItem.shown

    Badge {
        readonly property int offset: Math.round(Math.max(Kirigami.Units.smallSpacing / 2, parent.width / 32))
        id: badgeRect
        anchors.right: Qt.application.layoutDirection === Qt.RightToLeft ? undefined : parent.right
        anchors.left: Qt.application.layoutDirection === Qt.RightToLeft ? parent.left : undefined
        y: offset + (shiftBadgeDown ? (icon.height/2) : 0)
        height: Math.round(parent.height * 0.4)
        visible: task.smartLauncherItem.countVisible
        number: task.smartLauncherItem.count
    }
}
