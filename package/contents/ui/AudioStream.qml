/*
    SPDX-FileCopyrightText: 2017 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15

import org.kde.ksvg as KSvg
import org.kde.kirigami 2.20 as Kirigami
import Qt5Compat.GraphicalEffects

MouseArea {
    property string dominantIconColor
    id: audioStreamIconBox
    hoverEnabled: true
    onClicked: toggleMuted()

    // Using States rather than a simple Behavior we can apply different transitions,
    // which allows us to delay showing the icon but hide it instantly still.
    states: [
        State {
            name: "playing"
            when: task.playingAudio && !task.muted
            PropertyChanges {
                target: audioStreamIconBox
                opacity: 1
            }
            PropertyChanges {
                target: audioStreamIcon
                elementId: "audio-volume-high"
            }
        },
        State {
            name: "muted"
            when: task.muted
            PropertyChanges {
                target: audioStreamIconBox
                opacity: 1
            }
            PropertyChanges {
                target: audioStreamIcon
                elementId: "audio-volume-muted"
            }
        }
    ]

    transitions: [
        Transition {
             from: ""
             to: "playing"
             SequentialAnimation {
                 // Delay showing the play indicator so we don't flash it for brief sounds.
                 PauseAnimation {
                     duration: !task.delayAudioStreamIndicator || inPopup ? 0 : 2000
                 }
                 NumberAnimation {
                     property: "opacity"
                     duration: Kirigami.Units.longDuration
                 }
             }
        },
        Transition {
             from: ""
             to: "muted"
             SequentialAnimation {
                 NumberAnimation {
                     property: "opacity"
                     duration: Kirigami.Units.longDuration
                 }
             }
        },
        Transition {
             to: ""
             NumberAnimation {
                 property: "opacity"
                 duration: Kirigami.Units.longDuration
             }
        }
    ]

    opacity: 0
    visible: opacity > 0

    KSvg.FrameSvgItem {
        id: audioStreamFrame
        anchors.fill: audioStreamIcon
        visible: parent.containsMouse && !plasmoid.configuration.buttonColorize ? true : false
        imagePath: "widgets/viewitem"
        prefix: "hover"
    }

    ColorOverlay {
        id: colorOverrideAudio
        anchors.fill: audioStreamFrame
        source: audioStreamFrame
        color: plasmoid.configuration.buttonColorizeDominant ? dominantIconColor : plasmoid.configuration.buttonColorizeCustom
        visible: parent.containsMouse && plasmoid.configuration.buttonColorize ? true : false
    }

    KSvg.Svg {
        id: audioSvg
        imagePath: "icons/audio"
    }

    KSvg.SvgItem {
        id: audioStreamIcon

        // Need audio indicator twice, to keep iconBox in the center.
        readonly property var requiredSpace: Math.min(iconBox.width, iconBox.height)
                                             + Math.min(Math.min(iconBox.width, iconBox.height), Kirigami.Units.iconSizes.smallMedium) * 2
        svg: audioSvg
        smooth: false

        height: Math.round(Math.min(parent.height * indicatorScale, Kirigami.Units.iconSizes.smallMedium))
        width: height

        anchors {
            verticalCenter: parent.verticalCenter
            horizontalCenter: parent.horizontalCenter
        }

        states: [
            State {
                name: "verticalIconsOnly"
                when: tasks.vertical && frame.width < audioStreamIcon.requiredSpace

                PropertyChanges {
                    target: audioStreamIconLoader
                    anchors.rightMargin: Math.round(taskFrame.margins.right * indicatorScale)
                }
            },

            State {
                name: "horizontal"
                when: frame.width > audioStreamIcon.requiredSpace

                AnchorChanges {
                    target: audioStreamIconLoader

                    anchors.top: undefined
                    anchors.verticalCenter: frame.verticalCenter
                }

                PropertyChanges {
                    target: audioStreamIconLoader
                    width: Math.round(Math.min(Math.min(iconBox.width, iconBox.height), Kirigami.Units.iconSizes.smallMedium))
                }

                PropertyChanges {
                    target: audioStreamIcon

                    height: parent.height
                    width: parent.width
                }
            },

            State {
                name: "vertical"
                when: frame.height > audioStreamIcon.requiredSpace

                AnchorChanges {
                    target: audioStreamIconLoader

                    anchors.right: undefined
                    anchors.horizontalCenter: frame.horizontalCenter
                }

                PropertyChanges {
                    target: audioStreamIconLoader

                    anchors.topMargin: taskFrame.margins.top
                    width: Math.round(Math.min(Math.min(iconBox.width, iconBox.height), Kirigami.Units.iconSizes.smallMedium))
                }

                PropertyChanges {
                    target: audioStreamIcon

                    height: parent.height
                    width: parent.width
                }
            }
        ]
    }
}
