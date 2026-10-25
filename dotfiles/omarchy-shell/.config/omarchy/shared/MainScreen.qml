import QtQuick
import Quickshell
import Quickshell.Io

// The monitor named by "mainScreen" (a screen model, e.g. "Odyssey G80SH") in shell.json. Neither Omarchy nor
// Hyprland has a primary monitor, so the plugins that should only appear on one screen all read it from here.
// Symlinked into each plugin folder that needs it; `screen` is null when that monitor is not connected.
Item {
  id: root

  property string model: ""
  readonly property var screen: {
    var screens = Quickshell.screens || []
    if (!model) return null
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && screens[i].model === model) return screens[i]
    }
    return null
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        root.model = String(JSON.parse(text()).mainScreen || "")
      } catch (e) {
        root.model = ""
      }
    }
    onFileChanged: reload()
  }
}
