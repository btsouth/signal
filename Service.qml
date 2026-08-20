import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root
  property var settings: ({})
  property bool loading: false
  property string state: "loading"
  property string message: "Checking production…"
  property string organization: ""
  property string fetchedAt: ""
  property string environment: ""
  property bool stale: false
  property var rateLimit: null
  property var issues: []
  property string actionIssueId: ""
  property string actionMessage: ""
  property bool refreshQueued: false
  readonly property int unresolvedCount: issues.length
  readonly property int regressionCount: issues.filter(function(issue) { return issue.isRegression }).length
  readonly property int escalatingCount: issues.filter(function(issue) { return issue.isEscalating }).length
  readonly property int eventCount: Model.totalEvents(issues)
  readonly property int userCount: Model.affectedUsers(issues)
  readonly property bool alarming: regressionCount > 0
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 300, 60, 3600)

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }
  function intSetting(name, fallback, min, max) {
    var value = parseInt(String(setting(name, fallback)), 10)
    return isFinite(value) ? Math.max(min, Math.min(max, value)) : fallback
  }
  function boolSetting(name, fallback) {
    var value = setting(name, fallback)
    if (value === true || value === false) return value
    return /^(true|yes|on|1)$/i.test(String(value))
  }
  function helperPath(name) {
    return Qt.resolvedUrl("scripts/" + name).toString().replace(/^file:\/\//, "")
  }
  function refresh() {
    if (fetcher.running || actor.running) { refreshQueued = true; return }
    loading = true
    var command = [helperPath("signal-api"), "--action", "fetch", "--environment", String(setting("environment", "production")), "--limit", String(intSetting("maxIssues", 50, 10, 100)), "--sort", sentrySort()]
    if (boolSetting("demoMode", false)) command.push("--demo")
    else {
      var alertMode = String(setting("alertMode", "Regressions and escalating"))
      if (alertMode === "Regressions and escalating") command.push("--notify-escalating")
      else if (alertMode === "Regressions only") command.push("--notify")
    }
    fetcher.command = command
    fetcher.running = true
  }
  function act(action, issueId) {
    if (fetcher.running || actor.running || boolSetting("demoMode", false)) return
    actionIssueId = String(issueId || "")
    actionMessage = action === "resolve" ? "Resolving issue…" : "Ignoring issue…"
    actor.command = [helperPath("signal-api"), "--action", action, "--issue", actionIssueId]
    actor.running = true
  }
  function apply(raw) {
    try {
      var data = JSON.parse(String(raw || ""))
      state = String(data.state || "error")
      message = String(data.message || "")
      organization = String(data.organization || "")
      fetchedAt = String(data.fetchedAt || "")
      environment = String(data.environment || setting("environment", "production"))
      stale = data.stale === true
      rateLimit = data.rateLimit || null
      issues = Model.normalizeIssues(data.issues)
    } catch (error) {
      state = "error"
      message = "Sentry returned an unreadable response."
      issues = []
    }
  }
  function sentrySort() {
    var value = String(setting("sortOrder", "Recommended"))
    if (value === "Last seen") return "date"
    if (value === "Events") return "freq"
    if (value === "Users") return "user"
    if (value === "Trending") return "trends"
    if (value === "First seen") return "new"
    return "recommended"
  }
  function openSetup() {
    Quickshell.execDetached(["omarchy-launch-terminal", "--title", "Signal setup", helperPath("signal-setup")])
  }

  visible: false

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
  Process {
    id: fetcher
    command: []
    stdout: StdioCollector { id: fetchOutput; waitForEnd: true }
    stderr: StdioCollector { id: fetchError; waitForEnd: true }
    onExited: function(exitCode) {
      root.loading = false
      if (String(fetchOutput.text || "").trim() !== "") root.apply(fetchOutput.text)
      else { root.state = "error"; root.message = String(fetchError.text || "Signal refresh failed.").trim() }
      if (root.refreshQueued) { root.refreshQueued = false; root.refresh() }
    }
  }
  Process {
    id: actor
    command: []
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    stderr: StdioCollector { id: actionError; waitForEnd: true }
    onExited: function(exitCode) {
      try {
        var data = JSON.parse(String(actionOutput.text || "{}"))
        root.actionMessage = String(data.message || (exitCode === 0 ? "Issue updated." : "Update failed."))
      } catch (error) { root.actionMessage = String(actionError.text || "Update failed.").trim() }
      root.actionIssueId = ""
      actionNotice.restart()
      root.refresh()
    }
  }
  Timer { id: actionNotice; interval: 3000; onTriggered: root.actionMessage = "" }
}
