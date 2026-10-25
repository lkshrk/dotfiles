import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // Dedicated workspaces (see ~/.config/hypr/rules.lua) always show, with an icon instead of a number.
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

  // Each screen owns its workspaces (see ~/.config/hypr/screens.lua); unknown screens show the main set.
  readonly property var screenWorkspaces: ({
    "Samsung Electric Company Odyssey G60SD HNAX800191": [10],
    "Samsung Electric Company Odyssey G60SD HNAX800182": [6, 7]
  })
  readonly property var mainWorkspaces: [1, 2, 3, 4, 5, 8, 9]
  readonly property var monitor: QsWindow.window ? Hyprland.monitorFor(QsWindow.window.screen) : null
  readonly property var owned: (monitor && screenWorkspaces[monitor.description]) || mainWorkspaces

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
