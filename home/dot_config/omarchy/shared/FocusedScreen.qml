import QtQuick
import Quickshell
import Quickshell.Hyprland

// The focused monitor's screen; while `hold` is true it stays put, so an open popup does not follow the cursor.
Item {
  id: root

  property bool hold: false
  property var screen: null

  readonly property var live: {
    var screens = Quickshell.screens || []
    var name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && screens[i].name === name) return screens[i]
    }
    return screens.length > 0 ? screens[0] : null
  }

  function follow() { if (!hold || screen === null || (Quickshell.screens || []).indexOf(screen) < 0) screen = live }
  onLiveChanged: follow()
  onHoldChanged: follow()
  // Quickshell leaves focusedMonitor null until its monitor list is loaded.
  Component.onCompleted: { Hyprland.refreshMonitors(); follow() }
}
