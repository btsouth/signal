const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const path = require("path")
const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*/m, "")
const model = {}
vm.runInNewContext(source, model)

const rows = model.normalizeIssues([
  { id: "1", level: "warning", title: "old", count: "2", userCount: 1, lastSeen: "2026-01-01" },
  { id: "2", level: "error", title: "regression", count: "5", userCount: 3, substatus: "regressed", lastSeen: "2026-01-02", stats: { "24h": [[1, 0], [2, 5]] } }
])
assert.equal(rows[0].id, "2")
assert.equal(rows[0].isRegression, true)
assert.equal(model.totalEvents(rows), 7)
assert.equal(model.affectedUsers(rows), 4)
assert.equal(rows[0].activityTotal, 5)
assert.equal(rows[0].activityRatio, 1)
console.log("model tests passed")
