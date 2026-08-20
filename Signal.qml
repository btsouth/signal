import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "tsouth89.signal"
  ipcTarget: "tsouth89.signal"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color healthy: foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property int cursorIndex: 0
  property bool cursorActive: false
  property string selectedProject: "all"
  property string lifecycleFilter: "all"
  property string query: ""
  property string pendingAction: ""
  property var pendingIssue: null
  readonly property var visibleIssues: filteredIssues()
  readonly property var selectedIssue: visibleIssues.length > 0 ? visibleIssues[Math.max(0, Math.min(cursorIndex, visibleIssues.length - 1))] : null

  function filteredIssues() {
    var needle = String(query || "").trim().toLowerCase()
    return signal.issues.filter(function(issue) {
      if (selectedProject !== "all" && issue.project !== selectedProject) return false
      if (lifecycleFilter === "attention" && !issue.isRegression && !issue.isEscalating && !issue.isNew) return false
      if (lifecycleFilter === "regressed" && !issue.isRegression) return false
      if (lifecycleFilter === "escalating" && !issue.isEscalating) return false
      if (lifecycleFilter === "ongoing" && (issue.isRegression || issue.isEscalating || issue.isNew)) return false
      if (needle !== "") {
        var haystack = [issue.shortId, issue.title, issue.culprit, issue.project, issue.assignedTo, issue.lastRelease].join(" ").toLowerCase()
        if (haystack.indexOf(needle) === -1) return false
      }
      return true
    })
  }
  function projects() {
    var values = ["all"]
    for (var i = 0; i < signal.issues.length; i++) if (values.indexOf(signal.issues[i].project) === -1) values.push(signal.issues[i].project)
    return values
  }
  function moveCursor(delta) {
    cursorActive = true
    if (visibleIssues.length === 0) return
    cursorIndex = Math.max(0, Math.min(visibleIssues.length - 1, cursorIndex + delta))
  }
  function activateCursor() { if (selectedIssue) openIssue(selectedIssue) }
  function openIssue(issue) {
    if (!issue || issue.permalink === "") return
    Quickshell.execDetached(["omarchy-launch-browser", issue.permalink])
    close()
  }
  function requestAction(action, issue) {
    if (!issue || signal.boolSetting("demoMode", false)) return
    pendingAction = action
    pendingIssue = issue
    confirmDialog.message = (action === "resolve" ? "Resolve " : "Archive ") + issue.shortId + "?\n\n" + issue.title
    confirmDialog.confirmText = action === "resolve" ? "Resolve" : "Archive"
    confirmDialog.selectedIndex = 0
    confirmDialog.opened = true
  }
  function resolveSelected() { requestAction("resolve", selectedIssue) }
  function ignoreSelected() { requestAction("ignore", selectedIssue) }
  function clearPendingAction() { confirmDialog.opened = false; pendingAction = ""; pendingIssue = null }
  function relativeTime(value) {
    var then = new Date(String(value || "")).getTime()
    if (!isFinite(then)) return ""
    var seconds = Math.max(0, Math.floor((Date.now() - then) / 1000))
    if (seconds < 60) return "now"
    if (seconds < 3600) return Math.floor(seconds / 60) + "m"
    if (seconds < 86400) return Math.floor(seconds / 3600) + "h"
    return Math.floor(seconds / 86400) + "d"
  }
  function compactNumber(value) {
    value = Number(value || 0)
    if (value >= 1000000) return (value / 1000000).toFixed(value >= 10000000 ? 0 : 1) + "m"
    if (value >= 1000) return (value / 1000).toFixed(value >= 10000 ? 0 : 1) + "k"
    return String(value)
  }
  function severityColor(issue) {
    if (!issue) return dim
    if (issue.isRegression || issue.level === "fatal") return urgent
    if (issue.level === "error") return Qt.tint(urgent, Qt.rgba(foreground.r, foreground.g, foreground.b, 0.28))
    return dim
  }
  function lifecycleLabel(issue) {
    if (issue.isRegression) return "REGRESSED"
    if (issue.isEscalating) return "ESCALATING"
    if (issue.isNew) return "NEW"
    return "ONGOING"
  }

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight
  onVisibleIssuesChanged: cursorIndex = Math.max(0, Math.min(cursorIndex, visibleIssues.length - 1))
  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    signal.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service { id: signal; settings: root.settings }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { signal.refresh(); return "ok" }
    function status(): string { return JSON.stringify({state:signal.state,issues:signal.unresolvedCount,regressions:signal.regressionCount}) }
  }

  BarIconButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    text: signal.alarming ? "󰅚" : (signal.unresolvedCount > 0 ? "󰋼" : "󰄬")
    active: signal.alarming || signal.escalatingCount > 0
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) signal.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(650))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: search.activeFocus || confirmDialog.opened
      Keys.onPressed: function(event) { if (confirmDialog.handleKey(event)) event.accepted = true }
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTextKey: function(text) {
        if (text === "r" || text === "R") signal.refresh()
        else if (text === "x" || text === "X") root.resolveSelected()
        else if (text === "i" || text === "I") root.ignoreSelected()
        else if (text === "/") Qt.callLater(function() { search.forceActiveFocus() })
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: signal.organization !== "" ? "Signal · " + signal.organization : "Signal"
            meta: signal.loading ? "LISTENING FOR PRODUCTION" : (signal.state === "ready" ?
              (signal.regressionCount > 0 ? signal.regressionCount + " REGRESSION" + (signal.regressionCount === 1 ? "" : "S") :
               signal.escalatingCount > 0 ? signal.escalatingCount + " ESCALATING" :
               signal.unresolvedCount > 0 ? signal.unresolvedCount + " UNRESOLVED" : "PRODUCTION IS QUIET") : signal.message)
            detail: signal.stale ? "OFFLINE" : (signal.state === "ready" ? (signal.userCount > 0 ? compactNumber(signal.userCount) + " users" : "healthy") : "")
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Item {
                implicitWidth: Style.space(48)
                implicitHeight: Style.space(48)
                Rectangle {
                  anchors.centerIn: parent
                  width: Style.space(42); height: width; radius: width / 2
                  color: "transparent"
                  border.width: Math.max(1, Style.normalBorderWidth)
                  border.color: (signal.alarming || signal.escalatingCount > 0) ? root.urgent : root.dim
                  Rectangle {
                    anchors.centerIn: parent
                    width: (signal.alarming || signal.escalatingCount > 0) ? Style.space(14) : Style.space(8)
                    height: width; radius: width / 2
                    color: (signal.alarming || signal.escalatingCount > 0) ? root.urgent : root.foreground
                    SequentialAnimation on opacity {
                      running: signal.alarming || signal.escalatingCount > 0
                      loops: Animation.Infinite
                      NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                      NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                  }
                }
              }
            }
          }

          TextField {
            id: search
            visible: signal.state === "ready" && signal.issues.length > 0
            width: parent.width
            placeholderText: "Search issue, project, culprit, assignee, or release  ·  /"
            foreground: root.foreground
            text: root.query
            onTextChanged: { root.query = text; root.cursorIndex = 0 }
            Keys.onEscapePressed: { text = ""; keyCatcher.forceActiveFocus() }
          }

          Row {
            visible: signal.state === "ready" && signal.issues.length > 0
            width: parent.width
            spacing: Style.space(5)
            Repeater {
              model: [
                {id:"attention",label:"Attention"}, {id:"all",label:"All"},
                {id:"regressed",label:"Regressed"}, {id:"escalating",label:"Escalating"},
                {id:"ongoing",label:"Ongoing"}
              ]
              Button {
                required property var modelData
                text: modelData.label
                selected: root.lifecycleFilter === modelData.id
                foreground: root.foreground
                fontFamily: root.fontFamily
                horizontalPadding: Style.space(7)
                onClicked: { root.lifecycleFilter = modelData.id; root.cursorIndex = 0 }
              }
            }
          }

          Row {
            visible: signal.state === "ready" && signal.issues.length > 0
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: root.projects()
              Button {
                required property string modelData
                text: modelData === "all" ? "All " + signal.unresolvedCount : modelData
                selected: root.selectedProject === modelData
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: { root.selectedProject = modelData; root.cursorIndex = 0 }
              }
            }
          }

          Column {
            visible: signal.state === "ready" && root.visibleIssues.length > 0
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: root.visibleIssues
              delegate: BorderSurface {
                id: issueRow
                required property var modelData
                required property int index
                width: parent.width
                implicitHeight: issueContent.implicitHeight + Style.space(20)
                radius: Style.cornerRadius
                color: root.cursorActive && root.cursorIndex === index ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                borderSpec: root.cursorActive && root.cursorIndex === index ? Border.controlSpec("hover-cursor", root.foreground, Color.accent) : Border.controlSpec("normal", root.foreground, Color.accent)

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: { root.cursorActive = true; root.cursorIndex = issueRow.index }
                  onClicked: root.openIssue(issueRow.modelData)
                }

                Column {
                  id: issueContent
                  anchors.left: parent.left; anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(10)
                  spacing: Style.space(7)

                  RowLayout {
                    width: parent.width
                    spacing: Style.space(8)
                    Rectangle { width: Style.space(7); height: width; radius: width / 2; color: root.severityColor(issueRow.modelData) }
                    Text {
                      Layout.fillWidth: true
                      text: issueRow.modelData.title
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                    }
                    Text {
                      text: root.lifecycleLabel(issueRow.modelData)
                      color: root.severityColor(issueRow.modelData)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                    Text {
                      text: root.relativeTime(issueRow.modelData.lastSeen)
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                  RowLayout {
                    width: parent.width
                    spacing: Style.space(8)
                    Text {
                      Layout.fillWidth: true
                      text: issueRow.modelData.shortId + "  ·  " + issueRow.modelData.project + (issueRow.modelData.culprit !== "" ? "  ·  " + issueRow.modelData.culprit : "")
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideMiddle
                    }
                    Text {
                      text: root.compactNumber(issueRow.modelData.count) + " events  ·  " + root.compactNumber(issueRow.modelData.userCount) + " users"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                  Text {
                    visible: issueRow.modelData.assignedTo !== "" || issueRow.modelData.lastRelease !== "" || issueRow.modelData.priority !== ""
                    width: parent.width
                    text: (issueRow.modelData.assignedTo !== "" ? "Assigned " + issueRow.modelData.assignedTo : "Unassigned")
                      + (issueRow.modelData.priority !== "" ? "  ·  " + issueRow.modelData.priority + " priority" : "")
                      + (issueRow.modelData.lastRelease !== "" ? "  ·  " + issueRow.modelData.lastRelease : "")
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                  Canvas {
                    width: parent.width
                    height: Style.space(22)
                    onPaint: {
                      var ctx = getContext("2d")
                      ctx.clearRect(0, 0, width, height)
                      var points = Model.sparklinePoints(issueRow.modelData.stats, width, height - 2)
                      if (points.length < 2) return
                      ctx.strokeStyle = root.severityColor(issueRow.modelData)
                      ctx.lineWidth = Math.max(1, Style.normalBorderWidth)
                      ctx.beginPath(); ctx.moveTo(points[0].x, points[0].y + 1)
                      for (var i = 1; i < points.length; i++) ctx.lineTo(points[i].x, points[i].y + 1)
                      ctx.stroke()
                    }
                    Component.onCompleted: requestPaint()
                  }
                }
              }
            }
          }

          BorderSurface {
            visible: signal.state === "ready" && signal.issues.length > 0 && root.visibleIssues.length === 0
            width: parent.width
            implicitHeight: emptyFiltered.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
            color: "transparent"
            Text {
              id: emptyFiltered
              anchors.centerIn: parent
              text: "No issues match these filters."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
          }

          BorderSurface {
            visible: signal.state === "ready" && signal.issues.length === 0
            width: parent.width
            implicitHeight: quietColumn.implicitHeight + Style.space(32)
            radius: Style.cornerRadius
            borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
            color: "transparent"
            Column {
              id: quietColumn
              anchors.centerIn: parent
              spacing: Style.space(6)
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰄬"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.display }
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Nothing needs you."; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No unresolved issues in this environment."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }
            }
          }

          Column {
            visible: signal.state === "setup" || signal.state === "error"
            width: parent.width
            spacing: Style.space(10)
            Text { width: parent.width; wrapMode: Text.WordWrap; text: signal.message; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }
            Row {
              spacing: Style.space(8)
              Button { text: signal.state === "setup" ? "Connect Sentry" : "Reconnect"; iconText: "󰌘"; bordered: true; foreground: root.foreground; onClicked: signal.openSetup() }
              Button { text: "Try again"; iconText: "󰑐"; bordered: true; foreground: root.foreground; onClicked: signal.refresh() }
            }
          }

          RowLayout {
            visible: signal.state === "ready"
            width: parent.width
            Text {
              Layout.fillWidth: true
              text: signal.actionMessage !== "" ? signal.actionMessage : (signal.loading ? "Refreshing…" : (signal.stale ? signal.message : "↑↓ select  ·  Enter open  ·  / search  ·  X resolve  ·  I archive  ·  R refresh"))
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
            Button { visible: root.selectedIssue !== null && !signal.boolSetting("demoMode", false); text: "Resolve"; iconText: "󰄬"; foreground: root.foreground; onClicked: root.resolveSelected() }
            Button { visible: root.selectedIssue !== null && !signal.boolSetting("demoMode", false); text: "Archive"; iconText: "󰈉"; foreground: root.foreground; onClicked: root.ignoreSelected() }
          }
        }
      }

      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        z: 100
        foreground: root.foreground
        fontFamily: root.fontFamily
        onCanceled: root.clearPendingAction()
        onConfirmed: {
          var action = root.pendingAction
          var issue = root.pendingIssue
          root.clearPendingAction()
          if (issue) signal.act(action, issue.id)
        }
      }
    }
  }
}
