import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "lkshrk.workspaces"

  // The apps each workspace holds are in ~/.config/hypr/screens/config.lua (C.homes).
  readonly property var icons: ({
    1: { glyph: "\uDB80\uDC3B", name: "Apps" },
    2: { glyph: "\uDB80\uDD8D", name: "Terminal" },
    3: { glyph: "\uDB81\uDD9F", name: "Browser" },
    4: { glyph: "\uDB80\uDD69", name: "Editor" },
    5: { glyph: "\uDB82\uDD13", name: "Linear" },
    6: { glyph: "\uDB80\uDE8C", name: "Chat" },
    7: { glyph: "\uDB81\uDE6A", name: "Audio" },
    8: { glyph: "\uDB82\uDFC4", name: "Bitwarden" },
    9: { glyph: "\uDB84\uDF93", name: "Gaming" },
    10: { glyph: "\uDB80\uDDE7", name: "Browse & Notes" }
  })

  property var rules: []
  readonly property var monitor: QsWindow.window ? Hyprland.monitorFor(QsWindow.window.screen) : null
  readonly property var owned: {
    var mine = [], main = [], mainMonitor = ""
    for (var i = 0; i < rules.length; i++) {
      if (rules[i].workspaceString === "1") mainMonitor = rules[i].monitor
    }
    for (var j = 0; j < rules.length; j++) {
      var id = Number(rules[j].workspaceString), target = rules[j].monitor
      if (!(id > 0) || !target) continue
      if (monitor && (target === "desc:" + monitor.description || target === monitor.name)) mine.push(id)
      if (target === mainMonitor) main.push(id)
    }
    // A screen without workspace rules shows the set of the monitor that owns workspace 1.
    return mine.length ? mine : main
  }

  Process {
    id: rulesProc
    command: ["hyprctl", "workspacerules", "-j"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.rules = JSON.parse(String(text)) } catch (e) {}
      }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && event.name === "configreloaded" && !rulesProc.running) rulesProc.running = true
    }
  }

  function workspaceIds() {
    var ids = root.owned.slice()
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && ids.indexOf(id) === -1 && root.monitor && values[i].monitor === root.monitor) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property bool focused: root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id === modelData : false

        bar: root.bar
        readonly property var icon: root.icons[modelData] || null

        text: icon ? icon.glyph : (focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData)))
        tooltipText: icon ? icon.name : ""
        opacity: focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
