import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import org.kde.kirigami 2.19 as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kquickcontrols 2.0 as KQControls

ConfigPage {

    property int cfg_indicatorsEnabled: 1
    readonly property bool metroStyleSelected: indicatorStyle.currentIndex === 0
    readonly property bool cilioraStyleSelected: indicatorStyle.currentIndex === 1
    readonly property bool dashesStyleSelected: indicatorStyle.currentIndex === 2
    readonly property bool dotsStyleSelected: indicatorStyle.currentIndex === 3
    readonly property bool metroFamilyStyleSelected: metroStyleSelected
    readonly property bool shrinkControlsBrokenForStyle: metroStyleSelected || cilioraStyleSelected || dashesStyleSelected
    property alias cfg_groupIconEnabled: groupIconEnabled.currentIndex
    property alias cfg_indicatorProgress: indicatorProgress.checked
    property alias cfg_indicatorProgressColor: indicatorProgressColor.color
    property alias cfg_disableInactiveIndicators: disableInactiveIndicators.checked
    property alias cfg_indicatorsAnimated: indicatorsAnimated.checked
    property alias cfg_indicatorLocation: indicatorLocation.currentIndex
    property alias cfg_indicatorReverse: indicatorReverse.checked
    property alias cfg_indicatorOverride: indicatorOverride.checked
    property alias cfg_indicatorEdgeOffset: indicatorEdgeOffset.value
    property alias cfg_indicatorStyle: indicatorStyle.currentIndex
    property alias cfg_indicatorMinLimit: indicatorMinLimit.value
    property alias cfg_indicatorMaxLimit: indicatorMaxLimit.value
    property alias cfg_indicatorDesaturate: indicatorDesaturate.checked
    property alias cfg_indicatorGrow: indicatorGrow.checked
    property alias cfg_indicatorGrowFactor: indicatorGrowFactor.value
    property alias cfg_indicatorSize: indicatorSize.value
    property alias cfg_indicatorLength: indicatorLength.value
    property alias cfg_indicatorRadius: indicatorRadius.value
    property alias cfg_indicatorShrink: indicatorShrink.value
    property alias cfg_indicatorDominantColor: indicatorDominantColor.checked
    property alias cfg_indicatorAccentColor: indicatorAccentColor.checked
    property alias cfg_indicatorCustomColor: indicatorCustomColor.color

    onCfg_indicatorsEnabledChanged: {
        if (cfg_indicatorsEnabled !== 1) {
            cfg_indicatorsEnabled = 1
        }
    }

Kirigami.FormLayout {
    anchors.left: parent.left
    anchors.right: parent.right

    ComboBox {
        id: indicatorsEnabled
        Kirigami.FormData.label: i18n("Indicators:")
        model: [i18n("Disabled"), i18n("Enabled")]
        currentIndex: cfg_indicatorsEnabled
        enabled: false
    }

    CheckBox {
        id: indicatorProgress
        enabled: indicatorsEnabled.currentIndex
        visible: indicatorsEnabled.currentIndex
        text: i18n("Display Progress on Indicator")
    }

    KQControls.ColorButton {
        enabled: indicatorsEnabled.currentIndex
        visible: indicatorProgress.checked
        id: indicatorProgressColor
        Kirigami.FormData.label: i18n("Progress Color:")
        showAlphaChannel: true
    }

    CheckBox {
        enabled: indicatorsEnabled.currentIndex
        visible: indicatorsEnabled.currentIndex
        id: disableInactiveIndicators
        text: i18n("Disable for Inactive Windows")
    }

    ComboBox {
        id: groupIconEnabled
        Kirigami.FormData.label: i18n("Group Overlay:")
        model: [i18n("Disabled"), i18n("Enabled")]
    }
    Label {
        text: i18n("Takes effect on next time plasma groups tasks.")
        font: Kirigami.Theme.smallFont
    }

    Item {
        Kirigami.FormData.isSection: true
    }

    CheckBox {
        enabled: indicatorsEnabled.currentIndex
        id: indicatorsAnimated
        Kirigami.FormData.label: i18n("Animate Indicators:")
        text: i18n("Enabled")
    }


    Item {
        Kirigami.FormData.isSection: true
    }

    CheckBox {
        enabled: indicatorsEnabled.currentIndex && !indicatorOverride.checked
        id: indicatorReverse
        Kirigami.FormData.label: i18n("Indicator Location:")
        text: i18n("Reverse shown side")
    }

    CheckBox {
        enabled: indicatorsEnabled.currentIndex
        id: indicatorOverride
        text: i18n("Override location")
    }

    ComboBox {
        enabled: indicatorsEnabled.currentIndex
        visible: indicatorOverride.checked
        id: indicatorLocation
        model: [
            i18n("Bottom"),
            i18n("Left"),
            i18n("Right"),
            i18n("Top")
        ]
    }

    Label {
        text: i18n("Be sure to use this when using as a floating widget")
        font: Kirigami.Theme.smallFont
    }

    SpinBox {
        enabled: indicatorsEnabled.currentIndex
        id: indicatorEdgeOffset
        Kirigami.FormData.label: i18n("Indicator Edge Offset (px):")
        from: 0
        to: 999
    }

    Item {
        Kirigami.FormData.isSection: true
    }

    ComboBox {
        enabled: indicatorsEnabled.currentIndex
        id: indicatorStyle
        Kirigami.FormData.label: i18n("Indicator Style:")
        Layout.preferredWidth: Math.max(implicitContentWidth + Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 8)
        model: [
            i18n("Metro"),
            i18n("Ciliora"),
            i18n("Dashes"),
            i18n("Dots")
            ]
    }

    SpinBox {
        enabled: indicatorsEnabled.currentIndex
        id: indicatorMinLimit
        Kirigami.FormData.label: i18n("Indicator Min Limit:")
        from: 0
        to: 10
    }

    SpinBox {
        enabled: indicatorsEnabled.currentIndex
        id: indicatorMaxLimit
        Kirigami.FormData.label: i18n("Indicator Max Limit:")
        from: 1
        to: 10
    }

    CheckBox {
        enabled: indicatorsEnabled.currentIndex
        id: indicatorDesaturate
        Kirigami.FormData.label: i18n("Minimize Options:")
        text: i18n("Desaturate")
    }

    CheckBox {
        enabled: indicatorsEnabled.currentIndex && !shrinkControlsBrokenForStyle
        id: indicatorGrow
        text: i18n("Shrink when minimized")
    }

    SpinBox {
        id: indicatorGrowFactor
        enabled: indicatorsEnabled.currentIndex && !shrinkControlsBrokenForStyle
        visible: indicatorGrow.checked || shrinkControlsBrokenForStyle
        from: 100
        to: 10 * 100
        stepSize: 25
        Kirigami.FormData.label: i18n("Growth/Shrink factor:")

        property int decimals: 2
        property real realValue: value / 100

        validator: DoubleValidator {
            bottom: Math.min(indicatorGrowFactor.from, indicatorGrowFactor.to)
            top:  Math.max(indicatorGrowFactor.from, indicatorGrowFactor.to)
        }

        textFromValue: function(value, locale) {
            return Number(value / 100).toLocaleString(locale, 'f', indicatorGrowFactor.decimals)
        }

        valueFromText: function(text, locale) {
            return Number.fromLocaleString(locale, text) * 100
        }
    }

    Label {
        visible: indicatorsEnabled.currentIndex && (metroStyleSelected || cilioraStyleSelected)
        text: i18n("Metro and Ciliora currently ignore shrink-on-minimize and growth/shrink factor.")
        font: Kirigami.Theme.smallFont
    }

    Label {
        visible: indicatorsEnabled.currentIndex && dashesStyleSelected
        text: i18n("Dashes currently does not apply shrink/grow only when minimized, so these controls are disabled.")
        font: Kirigami.Theme.smallFont
    }

    Item {
        Kirigami.FormData.isSection: true
    }

    SpinBox {
        enabled: indicatorsEnabled.currentIndex
        id: indicatorSize
        Kirigami.FormData.label: i18n("Indicator size (px):")
        from: 1
        to: 999
    }

    SpinBox {
        enabled: indicatorsEnabled.currentIndex && !dotsStyleSelected && !cilioraStyleSelected
        id: indicatorLength
        Kirigami.FormData.label: i18n("Indicator length (px):")
        from: 1
        to: 999
    }

    Label {
        visible: indicatorsEnabled.currentIndex && metroFamilyStyleSelected
        text: i18n("In Metro, length is mainly visible for grouped windows with multiple indicator segments.")
        font: Kirigami.Theme.smallFont
    }

    Label {
        visible: indicatorsEnabled.currentIndex && cilioraStyleSelected
        text: i18n("Ciliora uses equal segmented bars across the available width, so length does not apply.")
        font: Kirigami.Theme.smallFont
    }

    SpinBox {
        enabled: indicatorsEnabled.currentIndex && !dotsStyleSelected
        id: indicatorRadius
        Kirigami.FormData.label: i18n("Indicator Radius (%):")
        from: 0
        to: 100
    }

    Label {
        visible: indicatorsEnabled.currentIndex && dotsStyleSelected
        text: i18n("Dots are always circular, so radius does not apply to this style.")
        font: Kirigami.Theme.smallFont
    }

    SpinBox {
        enabled: indicatorsEnabled.currentIndex && !dotsStyleSelected
        id: indicatorShrink
        Kirigami.FormData.label: i18n("Indicator margin (px):")
        from: 0
        to: 999
    }

    Label {
        visible: indicatorsEnabled.currentIndex && metroFamilyStyleSelected
        text: i18n("In Metro, margin mainly reduces the primary indicator segment.")
        font: Kirigami.Theme.smallFont
    }

    Label {
        visible: indicatorsEnabled.currentIndex && cilioraStyleSelected
        text: i18n("In Ciliora, margin reduces the overall segmented bar width.")
        font: Kirigami.Theme.smallFont
    }

    Label {
        visible: indicatorsEnabled.currentIndex && dashesStyleSelected
        text: i18n("In Dashes, margin mainly reduces the first dash.")
        font: Kirigami.Theme.smallFont
    }

    Label {
        visible: indicatorsEnabled.currentIndex && dotsStyleSelected
        text: i18n("Dots use Indicator size as the dot diameter. Length, radius, and margin do not apply.")
        font: Kirigami.Theme.smallFont
    }


    Item {
        Kirigami.FormData.isSection: true
    }

    CheckBox {
        enabled: indicatorsEnabled.currentIndex & !indicatorAccentColor.checked
        id: indicatorDominantColor
        Kirigami.FormData.label: i18n("Indicator Color:")
        text: i18n("Use dominant icon color")
    }

    CheckBox {
        enabled: indicatorsEnabled.currentIndex & !indicatorDominantColor.checked
        id: indicatorAccentColor
        text: i18n("Use plasma accent color")
    }

    KQControls.ColorButton {
        enabled: indicatorsEnabled.currentIndex & !indicatorDominantColor.checked & !indicatorAccentColor.checked
        id: indicatorCustomColor
        Kirigami.FormData.label: i18n("Custom Color:")
        showAlphaChannel: true
    }

    Item {
        Kirigami.FormData.isSection: true
    }
}
}
