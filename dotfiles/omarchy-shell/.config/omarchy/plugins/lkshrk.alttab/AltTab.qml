import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property int selectedIndex: 0
  property var windows: []
  // Window addresses (no 0x), most recently focused first.
  property var mru: []
  // A commit that arrives before its open (the two IPC calls race on a tap).
  property double pendingCommitAt: 0
  property double closedAt: 0
  // Omarchy sets no_screen_share on these, so their capture comes back blank.
  readonly property var protectedClass: /^(Bitwarden|1[pP]assword|chrome-nngceckbapebfimnlniiiahkandclblb-Default)$/

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color accent: Commons.Color.accent
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily

  property int previewHeight: Style.space(170)
  property int previewMaxWidth: Style.space(300)
  property int previewMinWidth: Style.space(110)
  property int cardPadding: Style.space(10)

  function normalize(address) {
    return String(address || "").replace(/^0x/, "")
  }

  function touch(address) {
    var key = normalize(address)
    if (!key) return
    var next = [key]
    for (var i = 0; i < mru.length; i++) if (mru[i] !== key) next.push(mru[i])
    mru = next
  }

  // Seeds the order for windows focused before the shell started.
  function historyRank(toplevel) {
    var ipc = toplevel.lastIpcObject
    return ipc && ipc.focusHistoryID !== undefined && ipc.focusHistoryID >= 0 ? ipc.focusHistoryID : 9999
  }

  function buildWindows() {
    var list = []
    var live = {}
    var all = Hyprland.toplevels.values
    for (var i = 0; i < all.length; i++) {
      var t = all[i]
      var ipc = t.lastIpcObject || {}
      // Hyprland.toplevels keeps closed windows; only a live wayland handle proves one exists.
      if (!t.wayland) continue
      live[normalize(t.address)] = true
      if (ipc.mapped === false || ipc.hidden === true) continue
      // Wine/XWayland helpers have neither class nor title and are no_focus anyway.
      if (!(ipc.class || ipc.initialClass) && !t.title) continue
      list.push(t)
    }
    mru = mru.filter(function(address) { return live[address] === true })
    var rank = {}
    for (var j = 0; j < mru.length; j++) rank[mru[j]] = j
    list.sort(function(a, b) {
      var ra = rank[normalize(a.address)], rb = rank[normalize(b.address)]
      if (ra !== undefined && rb !== undefined) return ra - rb
      if (ra !== undefined) return -1
      if (rb !== undefined) return 1
      return historyRank(a) - historyRank(b)
    })
    windows = list
  }

  function isProtected(toplevel) {
    var ipc = toplevel.lastIpcObject || {}
    return protectedClass.test(ipc.class || ipc.initialClass || "")
  }

  function open(delta) {
    if (!opened) {
      buildWindows()
      if (windows.length === 0) return
      // Start on the previous window, like Windows and macOS.
      selectedIndex = windows.length > 1 ? (delta < 0 ? windows.length - 1 : 1) : 0
      opened = true
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      if (Date.now() - pendingCommitAt < 400) commit()
      pendingCommitAt = 0
      return
    }
    step(delta)
  }

  function step(delta) {
    if (windows.length === 0) return
    selectedIndex = (selectedIndex + delta + windows.length) % windows.length
  }

  function commit() {
    if (!opened) {
      // The overlay and the release bind both commit; the second one must not arm the next open.
      if (Date.now() - closedAt > 400) pendingCommitAt = Date.now()
      return
    }
    var target = windows[selectedIndex]
    close()
    if (!target) return
    Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + normalize(target.address) + "\" })")
  }

  function close() {
    opened = false
    windows = []
    pendingCommitAt = 0
    closedAt = Date.now()
  }

  function iconFor(toplevel) {
    var ipc = toplevel.lastIpcObject || {}
    var cls = ipc.class || ipc.initialClass || ""
    var entry = cls ? DesktopEntries.heuristicLookup(cls) : null
    return Quickshell.iconPath(entry && entry.icon ? entry.icon : cls.toLowerCase(), "application-x-executable")
  }

  Component.onCompleted: {
    Hyprland.refreshToplevels()
    if (Hyprland.activeToplevel) touch(Hyprland.activeToplevel.address)
  }

  Connections {
    target: Hyprland
    function onActiveToplevelChanged() {
      if (Hyprland.activeToplevel) root.touch(Hyprland.activeToplevel.address)
    }
  }

  IpcHandler {
    target: "alttab"
    function next(): void { root.open(1) }
    function prev(): void { root.open(-1) }
    function commit(): void { root.commit() }
    function cancel(): void { root.close() }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    screen: {
      var name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
      var screens = Quickshell.screens
      for (var i = 0; i < screens.length; i++) if (screens[i].name === name) return screens[i]
      return screens.length > 0 ? screens[0] : null
    }
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "lkshrk-alttab"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) root.close()
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.commit()
        else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_H) root.step(-1)
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_L) root.step(1)
        else return
        event.accepted = true
      }
      Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) {
          event.accepted = true
          root.commit()
        }
      }
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: flow.width + padding * 2
      height: flow.implicitHeight + padding * 2
      radius: root.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: Style.spacing.panelPadding

      Flow {
        id: flow
        anchors.centerIn: parent
        width: Math.min(implicitRowWidth, panel.width - Style.gapsOut * 4)
        spacing: Style.spacing.md

        property real implicitRowWidth: {
          var w = 0
          for (var i = 0; i < repeater.count; i++) {
            var item = repeater.itemAt(i)
            if (item) w += item.width + (i > 0 ? spacing : 0)
          }
          return w
        }

        Repeater {
          id: repeater
          model: root.windows

          delegate: Rectangle {
            id: tile
            required property var modelData
            required property int index
            readonly property bool selected: index === root.selectedIndex
            readonly property var ipc: modelData.lastIpcObject || {}
            readonly property bool protectedWindow: root.isProtected(modelData)
            readonly property string icon: root.iconFor(modelData)
            readonly property real aspect: {
              var size = ipc.size
              if (!protectedWindow && preview.hasContent && preview.sourceSize.height > 0)
                return preview.sourceSize.width / preview.sourceSize.height
              return size && size[1] > 0 ? size[0] / size[1] : 16 / 10
            }

            width: Math.max(root.previewMinWidth, Math.min(root.previewMaxWidth, root.previewHeight * aspect)) + root.cardPadding * 2
            height: root.previewHeight + titleRow.height + root.cardPadding * 3
            radius: root.cornerRadius
            color: selected ? root.selectedBackground : "transparent"
            border.width: selected ? Math.max(2, Style.space(2)) : 0
            border.color: root.accent

            Item {
              id: previewBox
              x: root.cardPadding
              y: root.cardPadding
              width: parent.width - root.cardPadding * 2
              height: root.previewHeight

              ScreencopyView {
                id: preview
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height * tile.aspect)
                height: Math.min(parent.height, parent.width / tile.aspect)
                visible: !tile.protectedWindow
                captureSource: root.opened && !tile.protectedWindow ? tile.modelData.wayland : null
                live: false
                constraintSize: Qt.size(root.previewMaxWidth * 2, root.previewHeight * 2)
              }

              Image {
                anchors.centerIn: parent
                visible: tile.protectedWindow || !preview.hasContent
                width: Style.space(64)
                height: width
                sourceSize: Qt.size(width, height)
                source: tile.icon
              }
            }

            Row {
              id: titleRow
              x: root.cardPadding
              anchors.top: previewBox.bottom
              anchors.topMargin: root.cardPadding
              width: parent.width - root.cardPadding * 2
              spacing: Style.space(6)

              Image {
                id: smallIcon
                width: Style.font.body * 1.4
                height: width
                sourceSize: Qt.size(width, height)
                source: tile.icon
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                width: parent.width - smallIcon.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: tile.modelData.title || tile.ipc.class || ""
                color: tile.selected ? Commons.Color.menu.selectedText : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              onClicked: {
                root.selectedIndex = tile.index
                root.commit()
              }
            }
          }
        }
      }
    }
  }
}
