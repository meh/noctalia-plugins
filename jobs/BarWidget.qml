import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Rectangle {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    readonly property var main: pluginApi?.mainInstance ?? null
    readonly property var jobs: main?.jobs ?? ({})
    readonly property var jobIds: Object.keys(jobs).sort()
    readonly property int jobCount: jobIds.length

    // Only occupy space when there are active jobs
    visible: jobCount > 0
    implicitWidth: visible ? row.implicitWidth + Style.marginS * 2 : 0
    implicitHeight: Style.barHeight

    color: Style.capsuleColor
    radius: Style.radiusM

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Style.marginXS

        Repeater {
            model: root.jobIds

            delegate: SlotIndicator {
                required property string modelData  // job_id string
                job: root.jobs[modelData] ?? null
                jobId: modelData
                pluginApi: root.pluginApi
                screen: root.screen
                barRoot: root
            }
        }
    }
}

// ── Per-slot indicator ────────────────────────────────────────────────────────

component SlotIndicator: Item {
    id: slot

    property var job: null
    property string jobId: ""
    property var pluginApi: null
    property ShellScreen screen
    property var barRoot: null

    readonly property var main: pluginApi?.mainInstance ?? null
    readonly property string state: job?.state ?? ""
    readonly property bool isFinished: state === "finished"
    readonly property bool isPrompt: state === "prompt"
    readonly property bool isProgress: state === "progress"

    readonly property string displayColor: main?.resolveColor(job) ?? "#888888"

    implicitWidth: Style.barHeight * 0.7
    implicitHeight: Style.barHeight * 0.7

    // ── Progress arc (Canvas) ─────────────────────────────────────────────────

    Canvas {
        id: progressCanvas
        anchors.fill: parent
        visible: slot.isProgress

        readonly property real fraction: {
            var j = slot.job
            if (!j || j.total <= 0) return 0
            return Math.max(0, Math.min(1, j.current / j.total))
        }

        onFractionChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2
            var cy = height / 2
            var r = Math.min(width, height) / 2 - 1

            // Background track
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15)
            ctx.lineWidth = 2
            ctx.stroke()

            // Filled arc
            if (fraction > 0) {
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * fraction)
                ctx.closePath()
                ctx.fillStyle = slot.displayColor
                ctx.fill()
            }
        }
    }

    // ── Icon for non-progress states ──────────────────────────────────────────

    NIcon {
        id: stateIcon
        anchors.centerIn: parent
        visible: !slot.isProgress

        size: parent.width * 0.85

        icon: {
            switch (slot.state) {
            case "created":
            case "started":  return "circle-filled"
            case "stage":    return "circle-filled"
            case "prompt":   return "help-circle-filled"
            case "finished": return "circle-filled"
            default:         return "circle-filled"
            }
        }

        color: slot.displayColor

        // Pulse animation for prompt state
        SequentialAnimation on opacity {
            running: slot.isPrompt
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 750; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 750; easing.type: Easing.InOutSine }
        }

        opacity: slot.isPrompt ? 1.0 : 1.0
        onRunningChanged: if (!slot.isPrompt) opacity = 1.0
    }

    // ── Mouse interaction ─────────────────────────────────────────────────────

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: {
            if (slot.isFinished) {
                slot.main?.clearJob(slot.jobId)
            } else {
                slot.pluginApi?.openPanel(slot.screen, slot.barRoot)
            }
        }

        onEntered: {
            var job = slot.job
            if (!job) return
            var tip = ""
            // Build tooltip: show metadata name if available, then state
            var name = job.metadata?.name ?? job.metadata?.title ?? ""
            if (name) tip += name + "\n"
            tip += slot.state
            if (job.state === "progress" && job.total > 0)
                tip += " " + job.current + "/" + job.total
            else if (job.state === "stage" && job.stageName)
                tip += ": " + job.stageName
            else if (job.state === "prompt" && job.promptText)
                tip += ": " + job.promptText
            TooltipService.show(slot, tip.trim())
        }

        onExited: TooltipService.hide()
    }
}
