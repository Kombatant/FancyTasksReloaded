/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15

import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras 2.0 as PlasmaExtras

RowLayout {
    readonly property var player: mpris2Source.playerForLauncherUrl(launcherUrl, appPid)
    enabled: !!player && player.canControl

    readonly property bool playing: mpris2Source.isPlaying(player)
    property string parentTitle

    readonly property string track: player ? player.track : ""
    readonly property string artist: player ? player.artist : ""
    readonly property string albumArt: player ? player.artUrl : ""

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: isWin ? Kirigami.Units.smallSpacing : Kirigami.Units.largeSpacing
        spacing: 0

        ScrollableTextWrapper {
            id: songTextWrapper

            Layout.fillWidth: true
            Layout.preferredHeight: songText.height
            implicitWidth: songText.implicitWidth

            PlasmaComponents3.Label {
                id: songText
                parent: songTextWrapper
                width: parent.width
                height: undefined
                lineHeight: 1
                maximumLineCount: artistText.visible? 1 : 2
                wrapMode: Text.NoWrap
                elide: parent.state ? Text.ElideNone : Text.ElideRight
                text: track
                visible: !parentTitle.includes(track)
                textFormat: Text.PlainText
            }
        }

        ScrollableTextWrapper {
            id: artistTextWrapper

            Layout.fillWidth: true
            Layout.preferredHeight: artistText.height
            implicitWidth: artistText.implicitWidth
            visible: artistText.text !== ""

            PlasmaExtras.DescriptiveLabel {
                id: artistText
                parent: artistTextWrapper
                width: parent.width
                height: undefined
                wrapMode: Text.NoWrap
                lineHeight: 1
                elide: parent.state ? Text.ElideNone : Text.ElideRight
                text: artist
                font.pointSize: Math.max(1, Qt.application.font.pointSize - 1)
                textFormat: Text.PlainText
            }
        }
    }

    PlasmaComponents3.ToolButton {
        enabled: !!player && player.canGoPrevious
        icon.name: LayoutMirroring.enabled ? "media-skip-forward" : "media-skip-backward"
        onClicked: mpris2Source.goPrevious(player)
    }

    PlasmaComponents3.ToolButton {
        enabled: !!player && (playing ? player.canPause : player.canPlay)
        icon.name: playing ? "media-playback-pause" : "media-playback-start"
        onClicked: {
            if (!playing) {
                mpris2Source.play(player);
            } else {
                mpris2Source.pause(player);
            }
        }
    }

    PlasmaComponents3.ToolButton {
        enabled: !!player && player.canGoNext
        icon.name: LayoutMirroring.enabled ? "media-skip-backward" : "media-skip-forward"
        onClicked: mpris2Source.goNext(player)
    }
}
