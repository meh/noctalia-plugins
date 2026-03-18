import QtQuick
import Quickshell.Io

// Background singleton that subscribes to the zsa.oryx.Jobs DBus service via
// `gdbus monitor` and exposes the current job state to BarWidget and Panel.
//
// gdbus monitor output format for a State signal:
//   /zsa/oryx/Jobs: zsa.oryx.Jobs.State (uint32 3, 'progress', {'current': <uint32 50>, 'total': <uint32 100>})
Item {
    id: root

    property var pluginApi: null

    // Map of job_id (as string key) -> job object:
    //   { state, metadata, current, total, stageName, promptText, finishedValue }
    property var jobs: ({})

    readonly property int activeJobCount: Object.keys(jobs).length
    readonly property bool hasPrompts: {
        var vals = Object.values(jobs)
        for (var i = 0; i < vals.length; i++) {
            if (vals[i].state === "prompt") return true
        }
        return false
    }

    // ── Settings helpers ──────────────────────────────────────────────────────

    function setting(key) {
        return pluginApi?.pluginSettings?.[key]
            ?? pluginApi?.manifest?.metadata?.defaultSettings?.[key]
            ?? "#888888"
    }

    // ── Color utilities ───────────────────────────────────────────────────────

    // Parse "#RRGGBB" → [r, g, b] (0–255 each)
    function parseHex(hex) {
        var s = (hex || "#888888").replace("#", "")
        return [
            parseInt(s.substring(0, 2), 16),
            parseInt(s.substring(2, 4), 16),
            parseInt(s.substring(4, 6), 16)
        ]
    }

    // Lerp between two "#RRGGBB" colors by t ∈ [0, 1], returns "#RRGGBB"
    function lerpColor(hexA, hexB, t) {
        var a = parseHex(hexA)
        var b = parseHex(hexB)
        var r = Math.round(a[0] + (b[0] - a[0]) * t)
        var g = Math.round(a[1] + (b[1] - a[1]) * t)
        var bl = Math.round(a[2] + (b[2] - a[2]) * t)
        return "#" +
            ("0" + r.toString(16)).slice(-2) +
            ("0" + g.toString(16)).slice(-2) +
            ("0" + bl.toString(16)).slice(-2)
    }

    // Resolve the display color for a job given its current state.
    function resolveColor(job) {
        if (!job) return setting("colorIdle")
        switch (job.state) {
        case "created":
        case "started":
            return setting("colorStarted")
        case "progress":
            var t = job.total > 0 ? Math.max(0, Math.min(1, job.current / job.total)) : 0
            return lerpColor(setting("colorProgressStart"), setting("colorProgressEnd"), t)
        case "stage":
            return setting("colorStageDefault")
        case "prompt":
            return setting("colorPromptWaiting")
        case "finished":
            return setting("colorFinishedDefault")
        default:
            return setting("colorIdle")
        }
    }

    // ── GVariant dict parser ──────────────────────────────────────────────────

    // Extract a value from the GVariant dict string that gdbus monitor prints.
    // The dict looks like: {'key': <uint32 42>, 'other': <'hello'>}
    // We look for 'key': <...VALUE...> and extract VALUE (stripping type prefix).
    function extractDictValue(dict, key) {
        // Match 'key': <CONTENT> where CONTENT may contain nested <> for typed values
        var re = new RegExp("'" + key + "':\\s*<([^>]*)>")
        var m = dict.match(re)
        if (!m) return null
        var raw = m[1].trim()
        // Strip GVariant type prefixes: uint32 42 → "42", 'hello' → "hello"
        raw = raw.replace(/^u?int\d+\s+/, "")    // uint32 N, int32 N
        raw = raw.replace(/^double\s+/, "")        // double 1.0
        raw = raw.replace(/^byte\s+/, "")          // byte N
        raw = raw.replace(/^true$/, "true")
        raw = raw.replace(/^false$/, "false")
        // Strip surrounding quotes for strings
        var strMatch = raw.match(/^'(.*)'$/)
        if (strMatch) return strMatch[1]
        return raw
    }

    // ── Signal line parser ────────────────────────────────────────────────────

    function parseSignalLine(line) {
        // Only handle State signals from our object
        var m = line.match(/\/zsa\/oryx\/Jobs:\s+zsa\.oryx\.Jobs\.State\s+\((.+)\)$/)
        if (!m) return

        var args = m[1]

        // Extract job_id (first arg: uint32 N)
        var idMatch = args.match(/^uint32\s+(\d+)/)
        if (!idMatch) return
        var jobId = idMatch[1]  // keep as string for JS object key

        // Extract state string (second arg: 'state_name')
        var stateMatch = args.match(/uint32\s+\d+,\s+'(\w+)'/)
        if (!stateMatch) return
        var state = stateMatch[1]

        // Extract the dict portion (third arg: {...})
        var dictMatch = args.match(/\{(.*)\}$/)
        var dict = dictMatch ? ("{" + dictMatch[1] + "}") : "{}"

        if (state === "cleared") {
            var newJobs = Object.assign({}, jobs)
            delete newJobs[jobId]
            jobs = newJobs
            return
        }

        var job = Object.assign({}, jobs[jobId] || {
            state: "",
            metadata: {},
            current: 0,
            total: 0,
            stageName: "",
            promptText: "",
            finishedValue: null
        })

        job.state = state

        if (state === "created") {
            // Metadata is the whole dict — parse all key/value pairs
            var meta = {}
            var metaRe = /'([^']+)':\s*<([^>]*)>/g
            var mm
            while ((mm = metaRe.exec(dict)) !== null) {
                var v = mm[2].trim()
                v = v.replace(/^u?int\d+\s+/, "").replace(/^double\s+/, "")
                var sq = v.match(/^'(.*)'$/)
                meta[mm[1]] = sq ? sq[1] : v
            }
            job.metadata = meta
        } else if (state === "progress") {
            var cur = extractDictValue(dict, "current")
            var tot = extractDictValue(dict, "total")
            job.current = cur !== null ? parseInt(cur) : 0
            job.total = tot !== null ? parseInt(tot) : 0
        } else if (state === "stage") {
            job.stageName = extractDictValue(dict, "name") || ""
        } else if (state === "prompt") {
            job.promptText = extractDictValue(dict, "text") || ""
        } else if (state === "finished") {
            job.finishedValue = extractDictValue(dict, "value")
        }

        var updated = Object.assign({}, jobs)
        updated[jobId] = job
        jobs = updated
    }

    // ── DBus monitor process ──────────────────────────────────────────────────

    Process {
        id: monitorProcess
        command: ["gdbus", "monitor", "--session", "--dest", "zsa.oryx.Jobs",
                  "--object-path", "/zsa/oryx/Jobs"]
        running: true

        // Restart automatically if oryx-jobs daemon stops and restarts
        onRunningChanged: {
            if (!running) {
                // Brief delay before reconnecting so we don't spin on a missing service
                reconnectTimer.restart()
            }
        }

        stdout: SplitParser {
            onRead: line => root.parseSignalLine(line)
        }
    }

    Timer {
        id: reconnectTimer
        interval: 2000
        repeat: false
        onTriggered: monitorProcess.running = true
    }

    // ── One-shot call process ─────────────────────────────────────────────────
    // Re-exec()d for each PromptResolve / Clear call.

    Process {
        id: callProcess
    }

    // ── Public API ────────────────────────────────────────────────────────────

    function promptResolve(jobId, accepted) {
        callProcess.exec(["gdbus", "call",
            "--session",
            "--dest", "zsa.oryx.Jobs",
            "--object-path", "/zsa/oryx/Jobs",
            "--method", "zsa.oryx.Jobs.PromptResolve",
            jobId.toString(),
            accepted ? "true" : "false"])
    }

    function clearJob(jobId) {
        callProcess.exec(["gdbus", "call",
            "--session",
            "--dest", "zsa.oryx.Jobs",
            "--object-path", "/zsa/oryx/Jobs",
            "--method", "zsa.oryx.Jobs.Clear",
            jobId.toString()])
    }
}
