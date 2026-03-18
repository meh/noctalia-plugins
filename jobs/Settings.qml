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

    // Validate and normalise a hex color string.
    // Returns "#rrggbb" on success, null if invalid.
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

            // ── Section: General ──────────────────────────────────────────────

            NText {
                text: "Job Colors"
                pointSize: Style.fontSizeL
                font.weight: Font.Bold
                color: Color.mOnSurface
                topPadding: Style.marginS
            }

            NText {
                text: "Colors mirror the oryx-jobs configuration. Use #RRGGBB hex values."
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // ── Idle ──────────────────────────────────────────────────────────

            ColorRow {
                label: "Idle"
                description: "Icon color when no jobs are running"
                settingKey: "colorIdle"
                pluginApi: root.pluginApi
            }

            NDivider { Layout.fillWidth: true }

            // ── Started ───────────────────────────────────────────────────────

            ColorRow {
                label: "Started / Created"
                description: "Icon color while a job is running"
                settingKey: "colorStarted"
                pluginApi: root.pluginApi
            }

            NDivider { Layout.fillWidth: true }

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
                description: "Color at 0%"
                settingKey: "colorProgressStart"
                pluginApi: root.pluginApi
            }

            ColorRow {
                label: "Progress end"
                description: "Color at 100%"
                settingKey: "colorProgressEnd"
                pluginApi: root.pluginApi
            }

            NDivider { Layout.fillWidth: true }

            // ── Finished ──────────────────────────────────────────────────────

            ColorRow {
                label: "Finished"
                description: "Icon color after a job finishes (fallback)"
                settingKey: "colorFinishedDefault"
                pluginApi: root.pluginApi
            }

            NDivider { Layout.fillWidth: true }

            // ── Stage ─────────────────────────────────────────────────────────

            ColorRow {
                label: "Stage"
                description: "Icon color while a job is in a named stage"
                settingKey: "colorStageDefault"
                pluginApi: root.pluginApi
            }

            NDivider { Layout.fillWidth: true }

            // ── Prompt ────────────────────────────────────────────────────────

            NText {
                text: "Prompt"
                pointSize: Style.fontSizeM
                font.weight: Font.Medium
                color: Color.mOnSurface
                topPadding: Style.marginXS
            }

            ColorRow {
                label: "Prompt (waiting)"
                description: "Pulsing color while waiting for a response"
                settingKey: "colorPromptWaiting"
                pluginApi: root.pluginApi
            }

            ColorRow {
                label: "Prompt accept"
                description: "Accept button highlight color"
                settingKey: "colorPromptAccept"
                pluginApi: root.pluginApi
            }

            ColorRow {
                label: "Prompt reject"
                description: "Reject button highlight color"
                settingKey: "colorPromptReject"
                pluginApi: root.pluginApi
            }

            // Bottom padding
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

    readonly property string currentValue:
        pluginApi?.pluginSettings?.[settingKey]
            ?? pluginApi?.manifest?.metadata?.defaultSettings?.[settingKey]
            ?? "#888888"

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
                visible: colorRow.description !== ""
                text: colorRow.description
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
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

        // Hex text input
        NTextInput {
            id: hexInput
            implicitWidth: 100
            text: colorRow.currentValue
            placeholderText: "#rrggbb"

            onEditingFinished: {
                var norm = validateHex(text)
                if (norm) {
                    if (colorRow.pluginApi) {
                        colorRow.pluginApi.pluginSettings[colorRow.settingKey] = norm
                        colorRow.pluginApi.saveSettings()
                    }
                    text = norm
                } else {
                    text = colorRow.currentValue
                    ToastService.showError("Invalid color — use #RRGGBB format")
                }
            }
        }
    }

    function validateHex(s) {
        var m = s.trim().match(/^#?([0-9a-fA-F]{6})$/)
        return m ? ("#" + m[1].toLowerCase()) : null
    }
}
