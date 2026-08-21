.pragma library

function number(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) && parsed >= 0 ? Math.min(parsed, 9007199254740991) : fallback
}

// Sentry fields are remote input. Keep them plain, single-line and bounded before
// they ever reach layout, filtering, notifications, or browser-launch code.
function cleanText(value, fallback, maxLength) {
  var text = String(value === undefined || value === null || value === "" ? (fallback || "") : value)
  text = text.replace(/[\u0000-\u001f\u007f-\u009f\u200e\u200f\u202a-\u202e\u2066-\u2069]/g, " ")
  text = text.replace(/\s+/g, " ").trim()
  if (text.length > maxLength) text = text.slice(0, Math.max(0, maxLength - 1)) + "…"
  return text
}

function safePermalink(value) {
  var link = cleanText(value, "", 2048)
  return /^https:\/\/[^\s]+$/.test(link) ? link : ""
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
    id: cleanText(raw.id, "", 32),
    shortId: cleanText(raw.shortId || raw.id, "", 80),
    title: cleanText(raw.title || metadata.title, "Unknown error", 300),
    culprit: cleanText(raw.culprit || metadata.function, "", 200),
    level: cleanText(raw.level, "error", 32).toLowerCase(),
    status: cleanText(raw.status, "unresolved", 32),
    substatus: cleanText(raw.substatus, "ongoing", 32),
    permalink: safePermalink(raw.permalink),
    project: cleanText(project.slug || project.name || raw.project, "", 100),
    count: number(raw.count, 0),
    userCount: number(raw.userCount, 0),
    firstSeen: cleanText(raw.firstSeen, "", 64),
    lastSeen: cleanText(raw.lastSeen, "", 64),
    isUnhandled: raw.isUnhandled === true,
    isRegression: raw.substatus === "regressed" || raw.isRegression === true,
    isEscalating: raw.substatus === "escalating",
    isNew: raw.substatus === "new",
    assignedTo: raw.assignedTo ? cleanText(raw.assignedTo.name || raw.assignedTo.email || raw.assignedTo.id, "", 160) : "",
    priority: cleanText(raw.priority, "", 32),
    platform: cleanText(raw.platform || project.platform, "", 64),
    firstRelease: raw.firstRelease ? cleanText(raw.firstRelease.shortVersion || raw.firstRelease.version, "", 160) : "",
    lastRelease: raw.lastRelease ? cleanText(raw.lastRelease.shortVersion || raw.lastRelease.version, "", 160) : "",
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
