import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    implicitWidth: scroll.implicitWidth
    implicitHeight: scroll.implicitHeight

    function setting(key) {
        return pluginApi?.pluginSettings?.[key]
            ?? pluginApi?.manifest?.metadata?.defaultSettings?.[key]
            ?? "#888888"
    }

    function saveSetting(key, value) {
        if (pluginApi) {
            pluginApi.pluginSettings[key] = value
            pluginApi.saveSettings()
        }
    }

    // Validate and normalise a hex color string.
    // Returns the normalised "#RRGGBB" on success, or null if invalid.
    function validateHex(s) {
        var m = s.trim().match(/^#?([0-9a-fA-F]{6})$/)
        return m ? ("#" + m[1].toLowerCase()) : null
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true

        ColumnLayout {
            id: col
            width: scroll.width
            spacing: Style.marginM

            NText {
                text: "Job Colors"
                pointSize: Style.fontSizeL
                font.weight: Font.Bold
                color: Color.mOnSurface
                topPadding: Style.marginS
            }

            NText {
                text: "Colors match the oryx-jobs configuration. Use #RRGGBB hex values."
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // ── Idle ──────────────────────────────────────────────────────────

            ColorRow {
                label: "Idle"
                description: "LED color when no job is running"
                settingKey: "colorIdle"
                pluginApi: root.pluginApi
            }

            NHDivider {}

            // ── Started ───────────────────────────────────────────────────────

            ColorRow {
                label: "Started"
                description: "LED color when a job is running"
                settingKey: "colorStarted"
                pluginApi: root.pluginApi
            }

            NHDivider {}

            // ── Progress ──────────────────────────────────────────────────────

            NText {
                text: "Progress"
                pointSize: Style.fontSizeM
                font.weight: Font.Medium
                color: Color.mOnSurface
                topPadding: Style.marginXS
            }

            NText {
                text: "The icon color is linearly interpolated between Start (0%) and End (100%)."
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ColorRow {
                label: "Progress start"
                description: "Color at 0% progress"
                settingKey: "colorProgressStart"
                pluginApi: root.pluginApi
            }

            ColorRow {
                label: "Progress end"
                description: "Color at 100% progress"
                settingKey: "colorProgressEnd"
                pluginApi: root.pluginApi
            }

            NHDivider {}

            // ── Finished ──────────────────────────────────────────────────────

            ColorRow {
                label: "Finished"
                description: "LED color after a job finishes (fallback)"
                settingKey: "colorFinishedDefault"
                pluginApi: root.pluginApi
            }

            NHDivider {}

            // ── Stage ─────────────────────────────────────────────────────────

            ColorRow {
                label: "Stage"
                description: "LED color while a job is in a named stage"
                settingKey: "colorStageDefault"
                pluginApi: root.pluginApi
            }

            NHDivider {}

            // ── Prompt ────────────────────────────────────────────────────────

            NText {
                text: "Prompt"
                pointSize: Style.fontSizeM
                font.weight: Font.Medium
                color: Color.mOnSurface
                topPadding: Style.marginXS
            }

            ColorRow {
                label: "Prompt waiting"
                description: "Pulsing color while waiting for a response"
                settingKey: "colorPromptWaiting"
                pluginApi: root.pluginApi
            }

            ColorRow {
                label: "Prompt accept"
                description: "Flash color on accept"
                settingKey: "colorPromptAccept"
                pluginApi: root.pluginApi
            }

            ColorRow {
                label: "Prompt reject"
                description: "Flash color on reject"
                settingKey: "colorPromptReject"
                pluginApi: root.pluginApi
            }

            Item { implicitHeight: Style.marginM }
        }
    }
}

// ── Color row component ───────────────────────────────────────────────────────

component ColorRow: ColumnLayout {
    id: colorRow

    property string label: ""
    property string description: ""
    property string settingKey: ""
    property var pluginApi: null

    readonly property string currentValue: {
        pluginApi?.pluginSettings?.[settingKey]
            ?? pluginApi?.manifest?.metadata?.defaultSettings?.[settingKey]
            ?? "#888888"
    }

    Layout.fillWidth: true
    spacing: Style.marginXS

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            NText {
                text: colorRow.label
                pointSize: Style.fontSizeS
                color: Color.mOnSurface
            }

            NText {
                text: colorRow.description
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                visible: colorRow.description !== ""
            }
        }

        // Live color swatch
        Rectangle {
            width: 24
            height: 24
            radius: Style.radiusS
            color: colorRow.currentValue
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.15)
        }

        NTextInput {
            id: hexInput
            implicitWidth: 100
            text: colorRow.currentValue
            placeholderText: "#RRGGBB"

            onEditingFinished: {
                var norm = validateHex(text)
                if (norm) {
                    if (colorRow.pluginApi) {
                        colorRow.pluginApi.pluginSettings[colorRow.settingKey] = norm
                        colorRow.pluginApi.saveSettings()
                    }
                    text = norm
                } else {
                    // Reset to current valid value
                    text = colorRow.currentValue
                    ToastService.showError("Invalid color: use #RRGGBB format")
                }
            }
        }
    }

    function validateHex(s) {
        var m = s.trim().match(/^#?([0-9a-fA-F]{6})$/)
        return m ? ("#" + m[1].toLowerCase()) : null
    }
}
