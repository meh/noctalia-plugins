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

    implicitWidth: 340
    implicitHeight: content.implicitHeight + Style.marginL * 2

    ColumnLayout {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Style.marginL
        }
        spacing: Style.marginM

        // ── Header ────────────────────────────────────────────────────────────

        NText {
            text: "Jobs"
            pointSize: Style.fontSizeL
            font.weight: Font.Bold
            color: Color.mOnSurface
        }

        // ── Empty state ───────────────────────────────────────────────────────

        NText {
            visible: root.jobIds.length === 0
            text: "No active jobs"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            Layout.alignment: Qt.AlignHCenter
            topPadding: Style.marginM
            bottomPadding: Style.marginM
        }

        // ── Job cards ─────────────────────────────────────────────────────────

        Repeater {
            model: root.jobIds

            delegate: JobCard {
                required property string modelData  // job_id string
                jobId: modelData
                job: root.jobs[modelData] ?? null
                pluginApi: root.pluginApi
                Layout.fillWidth: true
            }
        }
    }
}

// ── Job card component ────────────────────────────────────────────────────────

component JobCard: Rectangle {
    id: card

    property string jobId: ""
    property var job: null
    property var pluginApi: null

    readonly property var main: pluginApi?.mainInstance ?? null
    readonly property string state: job?.state ?? ""
    readonly property var metadata: job?.metadata ?? ({})

    color: Color.mSurfaceVariant
    radius: Style.radiusM
    implicitWidth: cardLayout.implicitWidth + Style.marginM * 2
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

        // ── Header row: job ID + state chip ───────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
                text: "Job #" + card.jobId
                pointSize: Style.fontSizeS
                font.weight: Font.Medium
                color: Color.mOnSurface
            }

            Item { Layout.fillWidth: true }

            // State chip
            Rectangle {
                radius: Style.radiusS
                color: Qt.alpha(stateChipText.stateColor, 0.18)
                implicitWidth: stateChipText.implicitWidth + Style.marginS * 2
                implicitHeight: stateChipText.implicitHeight + Style.marginXS * 2

                NText {
                    id: stateChipText
                    anchors.centerIn: parent
                    text: card.state
                    pointSize: Style.fontSizeXS
                    font.weight: Font.Medium
                    color: stateColor

                    readonly property string stateColor: {
                        switch (card.state) {
                        case "started":
                        case "created":   return card.main?.resolveColor(card.job) ?? Color.mPrimary
                        case "progress":  return card.main?.resolveColor(card.job) ?? Color.mPrimary
                        case "stage":     return card.main?.resolveColor(card.job) ?? "#FFC800"
                        case "prompt":    return card.main?.resolveColor(card.job) ?? "#C800FF"
                        case "finished":  return card.main?.resolveColor(card.job) ?? Color.mOnSurfaceVariant
                        default:          return Color.mOnSurfaceVariant
                        }
                    }
                }
            }
        }

        // ── Metadata key-value pairs ──────────────────────────────────────────

        Repeater {
            model: Object.keys(card.metadata)

            delegate: RowLayout {
                required property string modelData  // key
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

        // ── Progress bar ──────────────────────────────────────────────────────

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
                }
                Item { Layout.fillWidth: true }
                NText {
                    text: (card.job?.current ?? 0) + " / " + (card.job?.total ?? 0)
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.12)

                Rectangle {
                    width: {
                        var j = card.job
                        if (!j || j.total <= 0) return 0
                        return parent.width * Math.max(0, Math.min(1, j.current / j.total))
                    }
                    height: parent.height
                    radius: parent.radius
                    color: card.main?.resolveColor(card.job) ?? Color.mPrimary

                    Behavior on width {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                }
            }
        }

        // ── Stage name ────────────────────────────────────────────────────────

        NText {
            visible: card.state === "stage"
            text: card.job?.stageName ?? ""
            pointSize: Style.fontSizeS
            color: card.main?.resolveColor(card.job) ?? "#FFC800"
            font.weight: Font.Medium
        }

        // ── Prompt ────────────────────────────────────────────────────────────

        ColumnLayout {
            visible: card.state === "prompt"
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
                text: card.job?.promptText ?? ""
                pointSize: Style.fontSizeS
                color: Color.mOnSurface
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIconButton {
                    icon: "check"
                    tooltip: "Accept"
                    iconColor: card.main?.setting("colorPromptAccept") ?? "#00FF00"
                    onClicked: card.main?.promptResolve(card.jobId, true)
                }

                NIconButton {
                    icon: "x"
                    tooltip: "Reject"
                    iconColor: card.main?.setting("colorPromptReject") ?? "#FF0000"
                    onClicked: card.main?.promptResolve(card.jobId, false)
                }
            }
        }

        // ── Finished ──────────────────────────────────────────────────────────

        RowLayout {
            visible: card.state === "finished"
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
                text: "Result: " + (card.job?.finishedValue ?? "")
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            NIconButton {
                icon: "trash"
                tooltip: "Clear"
                onClicked: card.main?.clearJob(card.jobId)
            }
        }
    }
}
