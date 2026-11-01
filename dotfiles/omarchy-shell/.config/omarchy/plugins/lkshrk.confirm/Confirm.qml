import Quickshell
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
  property string icon: ""
  property string title: ""
  property string message: ""
  property string confirmText: "Confirm"
  property string confirmIcon: ""
  property string cancelText: "Cancel"
  property string resultFile: ""
  property string doneFile: ""
  property int selectedIndex: 0

  property color accent: Commons.Color.accent
  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color scrim: Commons.Color.menu.scrim
  property string fontFamily: Style.font.menuFamily
  readonly property int cornerRadius: Style.cornerRadius
  readonly property int pad: Style.space(22)
  readonly property int buttonHeight: Style.space(40)

  function open(payloadJson) {
    if (root.opened) root.finish(false)
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    root.icon = String(payload.icon || "")
    root.title = String(payload.title || "")
    root.message = String(payload.message || "Are you sure?")
    root.confirmText = String(payload.confirmText || "Confirm")
    root.confirmIcon = String(payload.confirmIcon || "")
    root.cancelText = String(payload.cancelText || "Cancel")
    root.resultFile = String(payload.resultFile || "")
    root.doneFile = String(payload.doneFile || "")
    root.selectedIndex = payload.defaultConfirm ? 1 : 0
    root.opened = true
    intro.restart()
    if (root.icon) wiggle.restart()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.finish(false)
  }

  function finish(confirmed) {
    if (!root.opened) return
    root.opened = false
    wiggle.stop()
    if (!root.doneFile) return
    var write = root.resultFile ? "printf '%s\\n' " + (confirmed ? "yes" : "no") + " > " + Util.shellQuote(root.resultFile) + "; " : ""
    resultProc.command = ["bash", "-c", write + ": > " + Util.shellQuote(root.doneFile)]
    root.resultFile = ""
    root.doneFile = ""
    resultProc.running = true
  }

  Process { id: resultProc }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-confirm"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      id: scrimRect
      anchors.fill: parent
      color: root.scrim
      MouseArea { anchors.fill: parent; onClicked: root.finish(false) }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.finish(false)
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
          root.selectedIndex = root.selectedIndex === 0 ? 1 : 0
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.finish(root.selectedIndex === 1)
        } else {
          return
        }
        event.accepted = true
      }
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(380), panel.width - Style.gapsOut * 2)
      height: card.contentTopInset + card.contentBottomInset + body.implicitHeight
      anchors.centerIn: parent
      color: root.background
      borderSpec: Border.flat(Util.alpha(root.accent, 0.7), Math.max(1, Style.space(2)))
      padding: root.pad
      radius: root.cornerRadius
      transformOrigin: Item.Center

      MouseArea { anchors.fill: parent; onClicked: {} }

      ParallelAnimation {
        id: intro
        NumberAnimation { target: card; property: "scale"; from: 0.92; to: 1; duration: 180; easing.type: Easing.OutBack }
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutQuad }
        NumberAnimation { target: scrimRect; property: "opacity"; from: 0; to: 1; duration: 160 }
      }

      Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: card.contentTopInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        spacing: Style.space(14)

        Rectangle {
          visible: root.icon.length > 0
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.space(64)
          height: width
          radius: width / 2
          color: Util.alpha(root.accent, 0.14)
          border.color: Util.alpha(root.accent, 0.35)
          border.width: Math.max(1, Style.space(1))

          OpticalGlyph {
            id: bellGlyph
            anchors.centerIn: parent
            width: Style.space(34)
            height: width
            text: root.icon
            fontFamily: root.fontFamily
            fontSize: Style.space(32)
            color: root.accent
            transformOrigin: Item.Top
          }

          SequentialAnimation {
            id: wiggle
            loops: 3
            NumberAnimation { target: bellGlyph; property: "rotation"; to: 16; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { target: bellGlyph; property: "rotation"; to: -14; duration: 120; easing.type: Easing.InOutQuad }
            NumberAnimation { target: bellGlyph; property: "rotation"; to: 9; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: bellGlyph; property: "rotation"; to: 0; duration: 90; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 420 }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)

          Text {
            visible: root.title.length > 0
            width: parent.width
            textFormat: Text.PlainText
            text: root.title
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.message
            color: Util.alpha(root.foreground, root.title.length > 0 ? 0.7 : 1)
            font.family: root.fontFamily
            font.pixelSize: root.title.length > 0 ? Style.font.body : Style.font.title
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }

        Item { width: 1; height: Style.space(2) }

        Row {
          id: buttons
          width: parent.width
          spacing: Style.space(10)

          Repeater {
            model: [
              { label: root.cancelText, glyph: "" },
              { label: root.confirmText, glyph: root.confirmIcon }
            ]

            Rectangle {
              required property int index
              required property var modelData
              readonly property bool selected: root.selectedIndex === index
              readonly property bool primary: index === 1

              width: (buttons.width - buttons.spacing) / 2
              height: root.buttonHeight
              radius: root.cornerRadius
              color: primary
                ? (selected ? root.accent : Util.alpha(root.accent, 0.12))
                : (selected ? Util.alpha(root.foreground, 0.12) : "transparent")
              border.width: Math.max(1, Style.space(1))
              border.color: primary
                ? Util.alpha(root.accent, selected ? 1 : 0.55)
                : Util.alpha(root.foreground, selected ? 0.6 : 0.25)

              Behavior on color { ColorAnimation { duration: 110 } }

              Row {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  visible: modelData.glyph.length > 0
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: modelData.glyph
                  color: primary && selected ? root.background : (primary ? root.accent : root.foreground)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.iconLarge
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: primary && selected ? root.background : (primary ? root.accent : root.foreground)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: primary
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = index
                onClicked: root.finish(index === 1)
              }
            }
          }
        }
      }
    }
  }
}
