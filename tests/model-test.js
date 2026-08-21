const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const path = require("path")
const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*/m, "")
const model = {}
vm.runInNewContext(source, model)

const rows = model.normalizeIssues([
  { id: "1", level: "warning", title: "old", count: "2", userCount: 1, lastSeen: "2026-01-01" },
  { id: "2", level: "error", title: "regression", count: "5", userCount: 3, substatus: "regressed", lastSeen: "2026-01-02" }
])

const hostile = model.normalizeIssues([{
  id: "99",
  title: "<img src='https://attacker.invalid/pixel'>\u202e" + "x".repeat(400),
  culprit: "line\nfeed",
  project: {slug: "<b>remote</b>"},
  permalink: "file:///etc/passwd",
  count: -4,
  userCount: "not-a-number"
}])[0]
assert(hostile.title.includes("<img"), "plain text markup remains literal")
assert(!hostile.title.includes("\u202e"), "bidi controls stripped")
assert(hostile.title.length <= 300, "remote title bounded")
assert(hostile.culprit === "line feed", "controls normalized")
assert(hostile.project === "<b>remote</b>", "project remains literal plain text")
assert(hostile.permalink === "", "non-HTTPS link rejected")
assert(hostile.count === 0 && hostile.userCount === 0, "counts bounded")
assert.equal(rows[0].id, "2")
assert.equal(rows[0].isRegression, true)
assert.equal(model.totalEvents(rows), 7)
assert.equal(model.affectedUsers(rows), 4)
console.log("model tests passed")
