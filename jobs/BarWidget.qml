import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    readonly property var main: pluginApi?.mainInstance ?? null
    readonly property var jobs: main?.jobs ?? ({})
    readonly property var jobIds: Object.keys(jobs).sort()
    readonly property int jobCount: jobIds.length

    readonly property string screenName: screen?.name ?? ""
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    // Slot size: slightly smaller than the capsule so there's some breathing room
    readonly property real slotSize: Math.round(capsuleHeight * 0.65)

    readonly property real contentWidth: jobCount > 0
        ? (slotSize * jobCount) + (Style.marginXS * Math.max(0, jobCount - 1)) + Style.marginM * 2
        : capsuleHeight
    readonly property real contentHeight: capsuleHeight

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    // ── Visual capsule ────────────────────────────────────────────────────────

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        radius: Style.radiusL
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        // ── Active jobs: one slot indicator per job ───────────────────────────

        RowLayout {
            anchors.centerIn: parent
            spacing: Style.marginXS
            visible: root.jobCount > 0

            Repeater {
                model: root.jobIds

                delegate: SlotIndicator {
                    required property string modelData
                    jobId: modelData
                    job: root.jobs[modelData] ?? null
                    size: root.slotSize
                    main: root.main
                }
            }
        }

        // ── Idle: single icon ─────────────────────────────────────────────────

        NIcon {
            anchors.centerIn: parent
            visible: root.jobCount === 0
            icon: "circle-dashed"
            color: root.main?.setting("colorIdle") ?? "#888888"
            pointSize: root.slotSize * 0.85
            applyUiScale: false
        }
    }

    // ── Mouse area (covers full item for extended click target) ───────────────

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen)
            } else {
                pluginApi?.openPanel(root.screen, root)
            }
        }
    }

    // ── Context menu (right-click on idle widget) ─────────────────────────────

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": "Settings",
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)
            if (action === "settings")
                BarService.openPluginSettings(root.screen, pluginApi.manifest)
        }
    }

    // ── Slot indicator component ──────────────────────────────────────────────

    component SlotIndicator: Item {
        id: slot

        property string jobId: ""
        property var job: null
        property real size: 20
        property var main: null

        readonly property string state: job?.state ?? ""
        readonly property bool isProgress: state === "progress"
        readonly property bool isPrompt: state === "prompt"
        readonly property bool isFinished: state === "finished"
        readonly property string displayColor: main?.resolveColor(job) ?? "#888888"

        implicitWidth: size
        implicitHeight: size

        // Progress: pie-chart arc drawn on a Canvas
        Canvas {
            id: progressCanvas
            anchors.fill: parent
            visible: slot.isProgress

            readonly property real fraction: {
                var j = slot.job
                if (!j || j.total <= 0)
                    return 0
                return Math.max(0, Math.min(1, j.current / j.total))
            }

            onFractionChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var cx = width / 2
                var cy = height / 2
                var r  = Math.min(width, height) / 2 - 1

                // Background ring
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15)
                ctx.lineWidth = 2
                ctx.stroke()

                if (fraction > 0) {
                    // Filled arc from top (−π/2), clockwise
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * fraction)
                    ctx.closePath()
                    ctx.fillStyle = slot.displayColor
                    ctx.fill()
                }
            }
        }

        // All other states: icon
        NIcon {
            id: stateIcon
            anchors.centerIn: parent
            visible: !slot.isProgress
            applyUiScale: false

            pointSize: slot.size * 0.85

            icon: {
                switch (slot.state) {
                case "created":
                case "started":  return "circle-filled"
                case "stage":    return "circle-filled"
                case "prompt":   return "help-circle-filled"
                case "finished": return "circle-check-filled"
                default:         return "circle-filled"
                }
            }

            color: slot.displayColor

            // Opacity breath animation while waiting for prompt response
            SequentialAnimation on opacity {
                id: promptAnim
                running: slot.isPrompt
                loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 750; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
            }

            onVisibleChanged: {
                if (!slot.isPrompt)
                    opacity = 1.0
            }
        }

        // Tooltip on hover
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            // Clicks are handled by the parent MouseArea; this is tooltip-only
            propagateComposedEvents: true

            onEntered: {
                var j = slot.job
                if (!j)
                    return
                var tip = ""
                var name = j.metadata?.name ?? j.metadata?.title ?? j.metadata?.command ?? ""
                if (name)
                    tip += name + "\n"
                tip += slot.state
                if (j.state === "progress" && j.total > 0)
                    tip += " " + j.current + "/" + j.total
                else if (j.state === "stage" && j.stageName)
                    tip += ": " + j.stageName
                else if (j.state === "prompt" && j.promptText)
                    tip += ": " + j.promptText
                else if (j.state === "finished" && j.finishedValue !== null)
                    tip += " → " + j.finishedValue
                TooltipService.show(slot, tip.trim(), BarService.getTooltipDirection(root.screenName))
            }

            onExited: TooltipService.hide()

            onClicked: mouse => mouse.accepted = false
        }
    }
}
