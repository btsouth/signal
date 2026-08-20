.pragma library

function number(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) ? parsed : fallback
}

function severityRank(level) {
  var ranks = { fatal: 5, error: 4, warning: 3, info: 2, debug: 1 }
  return ranks[String(level || "").toLowerCase()] || 0
}

function normalizedIssue(raw) {
  raw = raw || {}
  var project = raw.project || {}
  var metadata = raw.metadata || {}
  return {
    id: String(raw.id || ""),
    shortId: String(raw.shortId || raw.id || ""),
    title: String(raw.title || metadata.title || "Unknown error"),
    culprit: String(raw.culprit || metadata.function || ""),
    level: String(raw.level || "error").toLowerCase(),
    status: String(raw.status || "unresolved"),
    substatus: String(raw.substatus || "ongoing"),
    permalink: String(raw.permalink || ""),
    project: String(project.slug || project.name || raw.project || ""),
    count: number(raw.count, 0),
    userCount: number(raw.userCount, 0),
    firstSeen: String(raw.firstSeen || ""),
    lastSeen: String(raw.lastSeen || ""),
    isUnhandled: raw.isUnhandled === true,
    isRegression: raw.substatus === "regressed" || raw.isRegression === true,
    isEscalating: raw.substatus === "escalating",
    isNew: raw.substatus === "new",
    assignedTo: raw.assignedTo ? String(raw.assignedTo.name || raw.assignedTo.email || raw.assignedTo.id || "") : "",
    priority: String(raw.priority || ""),
    platform: String(raw.platform || project.platform || ""),
    firstRelease: raw.firstRelease ? String(raw.firstRelease.shortVersion || raw.firstRelease.version || "") : "",
    lastRelease: raw.lastRelease ? String(raw.lastRelease.shortVersion || raw.lastRelease.version || "") : "",
    hasSeen: raw.hasSeen === true
  }
}

function normalizeIssues(rows) {
  if (!Array.isArray(rows)) return []
  var result = []
  for (var i = 0; i < rows.length; i++) {
    var issue = normalizedIssue(rows[i])
    if (issue.id !== "") result.push(issue)
  }
  result.sort(function(a, b) {
    if (a.isRegression !== b.isRegression) return a.isRegression ? -1 : 1
    if (a.isEscalating !== b.isEscalating) return a.isEscalating ? -1 : 1
    var severity = severityRank(b.level) - severityRank(a.level)
    if (severity !== 0) return severity
    return String(b.lastSeen).localeCompare(String(a.lastSeen))
  })
  return result
}

function totalEvents(rows) {
  var total = 0
  for (var i = 0; i < rows.length; i++) total += number(rows[i].count, 0)
  return total
}

function affectedUsers(rows) {
  var total = 0
  for (var i = 0; i < rows.length; i++) total += number(rows[i].userCount, 0)
  return total
}
