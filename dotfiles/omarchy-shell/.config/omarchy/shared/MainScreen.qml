import QtQuick
import Quickshell
import Quickshell.Io

// The shell.json "mainScreen" monitor (neither Omarchy nor Hyprland has a primary); null when not connected.
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
