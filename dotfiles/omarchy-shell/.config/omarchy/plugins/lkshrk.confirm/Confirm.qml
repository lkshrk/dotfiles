import Quickshell
import Quickshell.Wayland
import QtQuick
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
  property string token: ""
  property var answers: ({})
  property var answerOrder: []
  readonly property int answersKept: 8
  property bool wiggleIcon: false
  property int selectedIndex: 0

  property color accent: Commons.Color.accent
  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color scrim: Commons.Color.menu.scrim
  property string fontFamily: Commons.Style.font.menuFamily
  readonly property int cornerRadius: Commons.Style.cornerRadius
  readonly property int pad: Commons.Style.space(22)
  readonly property int buttonHeight: Commons.Style.space(40)

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    var token = String(payload.token || "")
    if (payload.openBy && Date.now() > Number(payload.openBy)) {
      root.remember(token, "gone")
      return
    }
    if (root.opened) root.finish("gone")
    root.token = token
    root.icon = String(payload.icon || "")
    root.title = String(payload.title || "")
    root.message = String(payload.message || "Are you sure?")
    root.confirmText = String(payload.confirmText || "Confirm")
    root.confirmIcon = String(payload.confirmIcon || "")
    root.cancelText = String(payload.cancelText || "Cancel")
    root.wiggleIcon = payload.wiggle === true
    root.selectedIndex = payload.defaultConfirm ? 1 : 0
    root.opened = true
    intro.restart()
    if (root.icon && root.wiggleIcon) wiggle.restart()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.finish("no")
  }

  function state(token) {
    if (!token) return "gone"
    if (root.opened && token === root.token) return "open"
    return root.answers[token] || "gone"
  }

  function dismiss(token) {
    if (token && root.opened && token === root.token) root.finish("no")
  }

  function remember(token, answer) {
    if (!token) return
    var next = ({})
    var order = root.answerOrder.filter(function(t) { return t !== token })
    order.push(token)
    if (order.length > root.answersKept) order = order.slice(order.length - root.answersKept)
    for (var i = 0; i < order.length; i++)
      next[order[i]] = order[i] === token ? answer : root.answers[order[i]]
    root.answers = next
    root.answerOrder = order
  }

  function finish(answer) {
    if (!root.opened) return
    root.opened = false
    wiggle.stop()
    root.remember(root.token, answer)
    root.token = ""
  }

  MainScreen { id: mainScreen }

  PanelWindow {
    id: panel
    visible: root.opened
    screen: mainScreen.screen
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
      MouseArea { anchors.fill: parent; onClicked: root.finish("no") }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.finish("no")
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
          root.selectedIndex = root.selectedIndex === 0 ? 1 : 0
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.finish(root.selectedIndex === 1 ? "yes" : "no")
        } else {
          return
        }
        event.accepted = true
      }
    }

    BorderSurface {
      id: card
      width: Math.min(Commons.Style.space(380), panel.width - Commons.Style.gapsOut * 2)
      height: card.contentTopInset + card.contentBottomInset + body.implicitHeight
      anchors.centerIn: parent
      color: root.background
      borderSpec: Commons.Border.flat(Commons.Util.alpha(root.accent, 0.7), Math.max(1, Commons.Style.space(2)))
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
        spacing: Commons.Style.space(14)

        Rectangle {
          visible: root.icon.length > 0
          anchors.horizontalCenter: parent.horizontalCenter
          width: Commons.Style.space(64)
          height: width
          radius: width / 2
          color: Commons.Util.alpha(root.accent, 0.14)
          border.color: Commons.Util.alpha(root.accent, 0.35)
          border.width: Math.max(1, Commons.Style.space(1))

          OpticalGlyph {
            id: iconGlyph
            anchors.centerIn: parent
            width: Commons.Style.space(34)
            height: width
            text: root.icon
            fontFamily: root.fontFamily
            fontSize: Commons.Style.space(32)
            color: root.accent
            transformOrigin: Item.Top
          }

          SequentialAnimation {
            id: wiggle
            loops: 3
            NumberAnimation { target: iconGlyph; property: "rotation"; to: 16; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { target: iconGlyph; property: "rotation"; to: -14; duration: 120; easing.type: Easing.InOutQuad }
            NumberAnimation { target: iconGlyph; property: "rotation"; to: 9; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: iconGlyph; property: "rotation"; to: 0; duration: 90; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 420 }
          }
        }

        Column {
          width: parent.width
          spacing: Commons.Style.space(4)

          Text {
            visible: root.title.length > 0
            width: parent.width
            textFormat: Text.PlainText
            text: root.title
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Commons.Style.font.display
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.message
            color: Commons.Util.alpha(root.foreground, root.title.length > 0 ? 0.7 : 1)
            font.family: root.fontFamily
            font.pixelSize: root.title.length > 0 ? Commons.Style.font.body : Commons.Style.font.title
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }

        Item { width: 1; height: Commons.Style.space(2) }

        Row {
          id: buttons
          width: parent.width
          spacing: Commons.Style.space(10)

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
              readonly property color textColor: primary && selected ? root.background : (primary ? root.accent : root.foreground)

              width: (buttons.width - buttons.spacing) / 2
              height: root.buttonHeight
              radius: root.cornerRadius
              color: primary
                ? (selected ? root.accent : Commons.Util.alpha(root.accent, 0.12))
                : (selected ? Commons.Util.alpha(root.foreground, 0.12) : "transparent")
              border.width: Math.max(1, Commons.Style.space(1))
              border.color: primary
                ? Commons.Util.alpha(root.accent, selected ? 1 : 0.55)
                : Commons.Util.alpha(root.foreground, selected ? 0.6 : 0.25)

              Behavior on color { ColorAnimation { duration: 110 } }

              Row {
                anchors.centerIn: parent
                spacing: Commons.Style.space(8)

                Text {
                  visible: modelData.glyph.length > 0
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: modelData.glyph
                  color: textColor
                  font.family: root.fontFamily
                  font.pixelSize: Commons.Style.font.iconLarge
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: textColor
                  font.family: root.fontFamily
                  font.pixelSize: Commons.Style.font.title
                  font.bold: primary
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = index
                onClicked: root.finish(index === 1 ? "yes" : "no")
              }
            }
          }
        }
      }
    }
  }
}
