/*
    SPDX-FileCopyrightText: 2025 FancyTasks Contributors

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import org.kde.pipewire 1.0 as PipeWire
import org.kde.taskmanager 0.1 as TaskManager

/**
 * Wayland window thumbnail via PipeWire screencasting.
 *
 * Expected context properties (set by the parent Loader):
 *   windowUuid  : string  – the Wayland window UUID
 *   isMinimized : bool    – whether the window is currently minimized
 */
Item {
    id: root
    anchors.fill: parent

    TaskManager.ScreencastingRequest {
        id: screencastRequest
        uuid: root.parent ? root.parent.windowUuid : ""
    }

    PipeWire.PipeWireSourceItem {
        id: pipeWireItem
        anchors.fill: parent
        nodeId: screencastRequest.nodeId
    }
}
