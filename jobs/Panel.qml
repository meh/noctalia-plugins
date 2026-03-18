import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    readonly property var main: pluginApi?.mainInstance ?? null
    readonly property var jobs: main?.jobs ?? ({})
    readonly property var jobIds: Object.keys(jobs).sort()

    // SmartPanel integration
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth: 400 * Style.uiScaleRatio
    property real contentPreferredHeight: Math.min(600, 120 + jobIds.length * 200) * Style.uiScaleRatio

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginM

            // ── Header ────────────────────────────────────────────────────────

            RowLayout {
                Layout.fillWidth: true

                NText {
                    text: "Jobs"
                    pointSize: Style.fontSizeL
                    font.weight: Font.Bold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                NText {
                    visible: root.jobIds.length > 0
                    text: root.jobIds.length === 1
                        ? "1 active"
                        : root.jobIds.length + " active"
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }
            }

            // ── Empty state ───────────────────────────────────────────────────

            Item {
                visible: root.jobIds.length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: 80

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Style.marginS

                    NIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "circle-dashed"
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeXL
                    }

                    NText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No active jobs"
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                    }
                }
            }

            // ── Job cards (scrollable) ────────────────────────────────────────

            NScrollView {
                visible: root.jobIds.length > 0
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    width: parent.width
                    spacing: Style.marginS

                    Repeater {
                        model: root.jobIds

                        delegate: JobCard {
                            required property string modelData
                            jobId: modelData
                            job: root.jobs[modelData] ?? null
                            main: root.main
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    // ── Job card component ────────────────────────────────────────────────────

    component JobCard: Rectangle {
        id: card

        property string jobId: ""
        property var job: null
        property var main: null

        readonly property string state: job?.state ?? ""
        readonly property var metadata: job?.metadata ?? ({})
        readonly property var metaKeys: Object.keys(metadata)
        readonly property string stateColor: main?.resolveColor(job) ?? Color.mOnSurfaceVariant

        color: Color.mSurfaceVariant
        radius: Style.radiusM
        implicitHeight: cardLayout.implicitHeight + Style.marginM * 2

        ColumnLayout {
            id: cardLayout
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Style.marginM
            }
            spacing: Style.marginS

            // ── Header: job ID + state chip ───────────────────────────────────

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                    icon: {
                        switch (card.state) {
                        case "created":
                        case "started":  return "loader-2"
                        case "progress": return "chart-pie-filled"
                        case "stage":    return "layers-subtract"
                        case "prompt":   return "help-circle-filled"
                        case "finished": return "circle-check-filled"
                        default:         return "circle-filled"
                        }
                    }
                    color: card.stateColor
                    pointSize: Style.fontSizeM

                    // Spin animation while running
                    RotationAnimation on rotation {
                        running: card.state === "started" || card.state === "created" || card.state === "stage"
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1800
                        direction: RotationAnimation.Clockwise
                    }

                    // Opacity pulse for prompt
                    SequentialAnimation on opacity {
                        running: card.state === "prompt"
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 750; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                    }

                    onVisibleChanged: {
                        if (card.state !== "prompt")
                            opacity = 1.0
                    }
                }

                NText {
                    text: "Job #" + card.jobId
                    pointSize: Style.fontSizeS
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                // State chip
                Rectangle {
                    radius: Style.radiusS
                    color: Qt.alpha(card.stateColor, 0.18)
                    implicitWidth: chipText.implicitWidth + Style.marginS * 2
                    implicitHeight: chipText.implicitHeight + 4

                    NText {
                        id: chipText
                        anchors.centerIn: parent
                        text: card.state
                        pointSize: Style.fontSizeXS
                        font.weight: Font.Medium
                        color: card.stateColor
                    }
                }
            }

            // ── Metadata key/value pairs ──────────────────────────────────────

            Repeater {
                model: card.metaKeys

                delegate: RowLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: Style.marginXS

                    NText {
                        text: modelData + ":"
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                    }

                    NText {
                        text: card.metadata[modelData] ?? ""
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            // ── Progress ──────────────────────────────────────────────────────

            ColumnLayout {
                visible: card.state === "progress"
                Layout.fillWidth: true
                spacing: Style.marginXS

                RowLayout {
                    Layout.fillWidth: true

                    NText {
                        text: "Progress"
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        Layout.fillWidth: true
                    }

                    NText {
                        text: (card.job?.current ?? 0) + " / " + (card.job?.total ?? 0)
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                    }
                }

                // Progress bar track
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.1)

                    // Progress fill
                    Rectangle {
                        width: {
                            var j = card.job
                            if (!j || j.total <= 0)
                                return 0
                            return parent.width * Math.max(0, Math.min(1, j.current / j.total))
                        }
                        height: parent.height
                        radius: parent.radius
                        color: card.stateColor

                        Behavior on width {
                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }

            // ── Stage ─────────────────────────────────────────────────────────

            NText {
                visible: card.state === "stage" && (card.job?.stageName ?? "") !== ""
                text: card.job?.stageName ?? ""
                pointSize: Style.fontSizeS
                color: card.stateColor
                font.weight: Font.Medium
                Layout.fillWidth: true
            }

            // ── Prompt ────────────────────────────────────────────────────────

            ColumnLayout {
                visible: card.state === "prompt"
                Layout.fillWidth: true
                spacing: Style.marginS

                // Question text
                Rectangle {
                    visible: (card.job?.promptText ?? "") !== ""
                    Layout.fillWidth: true
                    color: Qt.alpha(card.stateColor, 0.1)
                    radius: Style.radiusS
                    implicitHeight: promptTextLabel.implicitHeight + Style.marginS * 2

                    NText {
                        id: promptTextLabel
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: Style.marginS
                        }
                        text: card.job?.promptText ?? ""
                        pointSize: Style.fontSizeS
                        color: Color.mOnSurface
                        wrapMode: Text.WordWrap
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NButton {
                        text: "Accept"
                        highlighted: true
                        Layout.fillWidth: true
                        onClicked: card.main?.promptResolve(card.jobId, true)
                    }

                    NButton {
                        text: "Reject"
                        Layout.fillWidth: true
                        onClicked: card.main?.promptResolve(card.jobId, false)
                    }
                }
            }

            // ── Finished ──────────────────────────────────────────────────────

            RowLayout {
                visible: card.state === "finished"
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                    icon: "flag-filled"
                    color: card.stateColor
                    pointSize: Style.fontSizeS
                }

                NText {
                    text: "Result: " + (card.job?.finishedValue ?? "—")
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                NIconButton {
                    icon: "x"
                    onClicked: card.main?.clearJob(card.jobId)
                }
            }
        }
    }
}
