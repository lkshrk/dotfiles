import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// One-line port of the macOS Stats app: icon + value per module, each with its own popup.
BarWidget {
  id: root
  moduleName: "lkshrk.stats"

  readonly property int interval: setting("interval", 2)
  readonly property string diskMount: setting("disk", "/")
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")
  readonly property int historySize: 60

  property int cpu: 0
  property int cpuUser: 0
  property int cpuSystem: 0
  property int ram: 0
  property int disk: 0
  property real rx: 0
  property real tx: 0
  property real diskRead: 0
  property real diskWrite: 0

  property var cpuHistory: []
  property var ramHistory: []
  property var rxHistory: []
  property var txHistory: []
  property var readHistory: []
  property var writeHistory: []

  property var detail: null
  property string publicIp: ""
  property string openModule: ""

  function close() { openModule = "" }
  function toggle(name) { openModule = openModule === name ? "" : name }

  readonly property color barText: root.bar ? root.bar.barForeground : Commons.Color.foreground
  readonly property color popupText: Commons.Color.popups.text
  readonly property color muted: Commons.Color.muted
  readonly property color accent: Commons.Color.accent
  readonly property color downloadColor: "#3b82f6"
  readonly property color uploadColor: "#ef4444"
  readonly property color systemColor: "#ef4444"
  readonly property color userColor: "#3b82f6"
  readonly property color cacheColor: "#eab308"
  readonly property color idleColor: Qt.rgba(Commons.Color.muted.r, Commons.Color.muted.g, Commons.Color.muted.b, 0.35)

  function pushed(list, value) {
    var next = list.slice(Math.max(0, list.length - historySize + 1))
    next.push(value)
    return next
  }
  function scaled(value, units, base) {
    var unit = 0
    while (value >= base && unit < units.length - 1) {
      value /= base
      unit++
    }
    var digits = value === 0 || unit === 0 ? 0 : (value < 10 ? 2 : (value < 100 ? 1 : 0))
    return value.toFixed(digits) + " " + units[unit]
  }
  function speed(bytes) { return scaled(bytes, ["B/s", "KB/s", "MB/s", "GB/s"], 1000) }
  function size(bytes) { return scaled(bytes, ["B", "KB", "MB", "GB", "TB"], 1024) }
  function percentOf(part, whole) { return whole > 0 ? Math.round(part / whole * 100) + "%" : "–" }
  function duration(seconds) {
    var d = Math.floor(seconds / 86400), h = Math.floor(seconds % 86400 / 3600), m = Math.floor(seconds % 3600 / 60)
    return (d > 0 ? d + "d " : "") + h + "h " + m + "m"
  }
  function pressureLevel(avg10) {
    if (avg10 >= 30) return "Critical"
    if (avg10 >= 10) return "Warning"
    return "Normal"
  }

  Process {
    command: [root.pluginDir + "stats-feed", String(root.interval), root.diskMount]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        var p = String(line).trim().split(/\s+/).map(Number)
        if (p.length < 9) return
        root.cpu = p[0]; root.cpuUser = p[1]; root.cpuSystem = p[2]
        root.ram = p[3]; root.disk = p[4]
        root.rx = p[5]; root.tx = p[6]
        root.diskRead = p[7]; root.diskWrite = p[8]
        root.cpuHistory = root.pushed(root.cpuHistory, p[0])
        root.ramHistory = root.pushed(root.ramHistory, p[3])
        root.rxHistory = root.pushed(root.rxHistory, p[5])
        root.txHistory = root.pushed(root.txHistory, p[6])
        root.readHistory = root.pushed(root.readHistory, p[7])
        root.writeHistory = root.pushed(root.writeHistory, p[8])
      }
    }
  }

  Process {
    id: detailProc
    command: [root.pluginDir + "stats-detail", root.diskMount]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.detail = JSON.parse(String(text)) } catch (e) {}
      }
    }
  }

  Process {
    id: publicIpProc
    command: ["curl", "-fsS", "--max-time", "4", "https://api.ipify.org"]
    stdout: StdioCollector {
      onStreamFinished: {
        var ip = String(text).trim()
        if (ip !== "") root.publicIp = ip
      }
    }
  }

  function refreshPublicIp() { if (!publicIpProc.running) publicIpProc.running = true }
  onOpenModuleChanged: if (openModule === "net") refreshPublicIp()
  Component.onCompleted: refreshPublicIp()

  Timer {
    interval: root.interval * 1000
    running: root.openModule !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!detailProc.running) detailProc.running = true
  }

  implicitWidth: row.implicitWidth + Style.spaceReal(8)
  implicitHeight: root.barSize

  component BarText: Text {
    color: root.barText
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    verticalAlignment: Text.AlignVCenter
  }

  component Module: Item {
    id: module
    property string name
    default property alias content: inner.data
    property alias popupContent: popupColumn.data
    property int popupWidth: Style.space(300)
    readonly property bool active: root.openModule === module.name

    function close() { if (module.active) root.close() }

    implicitWidth: inner.implicitWidth
    implicitHeight: root.barSize

    RowLayout {
      id: inner
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spaceReal(1.5)
    }

    // Same mark the bar draws under a module with an open panel, but per stat.
    Rectangle {
      visible: opacity > 0
      opacity: module.active ? 0.9 : 0
      color: Commons.Color.accent
      width: Math.max(Style.space(10), Math.round(module.width * 0.55))
      height: Style.space(2)
      radius: height / 2
      x: Math.floor((module.width - width) / 2)
      y: module.height - height - Style.space(2)
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          root.close()
          if (root.bar) root.bar.run("uwsm-app -- missioncenter")
        } else {
          root.toggle(module.name)
        }
      }
    }

    PopupCard {
      id: popup
      anchorItem: module
      bar: root.bar
      owner: module
      open: module.active
      contentWidth: popup.fittedContentWidth(module.popupWidth)
      contentHeight: popup.fittedContentHeight(popupColumn.implicitHeight)

      ColumnLayout {
        id: popupColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(4)
      }
    }
  }

  component Heading: Text {
    Layout.topMargin: Style.space(6)
    color: root.popupText
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.bold: true
  }

  component Field: RowLayout {
    property string name
    property string value
    property color dot: "transparent"
    Layout.fillWidth: true
    spacing: Style.space(6)

    Rectangle {
      visible: parent.dot.a > 0
      width: 6
      height: 6
      radius: 3
      color: parent.dot
    }
    Text {
      Layout.fillWidth: true
      text: parent.name
      color: root.muted
      elide: Text.ElideRight
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      text: parent.value
      color: root.popupText
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
  }

  component History: StatsChart {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.space(70)
    grid: Qt.rgba(root.muted.r, root.muted.g, root.muted.b, 0.25)
    capacity: root.historySize
  }

  component DonutRow: RowLayout {
    property var slices: []
    property string centerText
    default property alias details: legend.data
    Layout.fillWidth: true
    spacing: Style.space(12)

    Item {
      Layout.preferredWidth: Style.space(84)
      Layout.preferredHeight: Style.space(84)
      StatsChart {
        anchors.fill: parent
        kind: "donut"
        slices: parent.parent.slices
        grid: Qt.rgba(root.muted.r, root.muted.g, root.muted.b, 0.25)
      }
      Text {
        anchors.centerIn: parent
        text: parent.parent.centerText
        color: root.popupText
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }
    ColumnLayout {
      id: legend
      Layout.fillWidth: true
      spacing: Style.space(4)
    }
  }

  component TopList: Repeater {
    id: topList
    property bool memory: false
    Field {
      required property var modelData
      name: modelData.name
      value: topList.memory ? root.size(modelData.value) : modelData.value.toFixed(1) + "%"
    }
  }

  Text { id: percentProbe; visible: false; text: "99%"; font.family: Style.font.family; font.pixelSize: Style.font.body }
  Text { id: speedProbe; visible: false; text: "999 KB/s"; font.family: Style.font.family; font.pixelSize: Style.font.body }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: Style.spaceReal(6)

    Module {
      name: "net"
      popupWidth: Style.space(320)
      BarText { text: "↑"; color: root.uploadColor }
      BarText { text: root.speed(root.tx); Layout.minimumWidth: speedProbe.implicitWidth; horizontalAlignment: Text.AlignLeft }
      BarText { text: "↓"; color: root.downloadColor; Layout.leftMargin: Style.spaceReal(4) }
      BarText { text: root.speed(root.rx); Layout.minimumWidth: speedProbe.implicitWidth; horizontalAlignment: Text.AlignLeft }

      popupContent: [
        Heading { text: "Network"; Layout.topMargin: 0 },
        History {
          series: [
            { values: root.rxHistory, color: root.downloadColor },
            { values: root.txHistory, color: root.uploadColor }
          ]
        },
        Field { name: "Downloading"; dot: root.downloadColor; value: root.speed(root.rx) },
        Field { name: "Uploading"; dot: root.uploadColor; value: root.speed(root.tx) },
        Heading { text: "Details" },
        Field { name: "Interface"; value: root.detail && root.detail.net.interface ? root.detail.net.interface : "–" },
        Field { name: "Local IP"; value: root.detail && root.detail.net.ip ? root.detail.net.ip : "–" },
        Field { name: "Public IP"; value: root.publicIp || "–" },
        Field { name: "Physical address"; value: root.detail && root.detail.net.mac ? root.detail.net.mac : "–" },
        Field { name: "DNS server"; value: root.detail && root.detail.net.dns ? root.detail.net.dns : "–" },
        Field { name: "Total download"; value: root.detail ? root.size(root.detail.net.totalDownload) : "–" },
        Field { name: "Total upload"; value: root.detail ? root.size(root.detail.net.totalUpload) : "–" }
      ]
    }

    Module {
      name: "cpu"
      BarText { text: "󰻠" }
      BarText { text: root.cpu + "%"; Layout.minimumWidth: percentProbe.implicitWidth }

      popupContent: [
        Heading { text: "CPU"; Layout.topMargin: 0 },
        History { max: 100; series: [{ values: root.cpuHistory, color: root.accent }] },
        DonutRow {
          centerText: root.cpu + "%"
          slices: [
            { value: root.cpuSystem, color: root.systemColor },
            { value: root.cpuUser, color: root.userColor },
            { value: Math.max(0, 100 - root.cpuSystem - root.cpuUser), color: root.idleColor }
          ]
          Field { name: "System"; dot: root.systemColor; value: root.cpuSystem + "%" }
          Field { name: "User"; dot: root.userColor; value: root.cpuUser + "%" }
          Field { name: "Idle"; dot: root.idleColor; value: Math.max(0, 100 - root.cpu) + "%" }
        },
        Heading { text: "Average load" },
        Field { name: "1 minute"; value: root.detail ? root.detail.cpu.load[0].toFixed(2) : "–" },
        Field { name: "5 minutes"; value: root.detail ? root.detail.cpu.load[1].toFixed(2) : "–" },
        Field { name: "15 minutes"; value: root.detail ? root.detail.cpu.load[2].toFixed(2) : "–" },
        Heading { text: "Details" },
        Field { name: "Frequency"; value: root.detail ? (root.detail.cpu.frequency / 1e9).toFixed(2) + " GHz" : "–" },
        Field { name: "Cores"; value: root.detail ? String(root.detail.cpu.cores) : "–" },
        Field { name: "Uptime"; value: root.detail ? root.duration(root.detail.cpu.uptime) : "–" },
        Heading { text: "Top processes" },
        TopList { model: root.detail ? root.detail.cpu.top : [] }
      ]
    }

    Module {
      name: "ram"
      BarText { text: "󰍛" }
      BarText { text: root.ram + "%"; Layout.minimumWidth: percentProbe.implicitWidth }

      popupContent: [
        Heading { text: "Memory"; Layout.topMargin: 0 },
        History { max: 100; series: [{ values: root.ramHistory, color: root.accent }] },
        DonutRow {
          centerText: root.ram + "%"
          slices: root.detail ? [
            { value: root.detail.ram.app, color: root.userColor },
            { value: root.detail.ram.cache, color: root.cacheColor },
            { value: root.detail.ram.free, color: root.idleColor }
          ] : []
          Field { name: "App"; dot: root.userColor; value: root.detail ? root.size(root.detail.ram.app) : "–" }
          Field { name: "Cache"; dot: root.cacheColor; value: root.detail ? root.size(root.detail.ram.cache) : "–" }
          Field { name: "Free"; dot: root.idleColor; value: root.detail ? root.size(root.detail.ram.free) : "–" }
        },
        Heading { text: "Details" },
        Field { name: "Used"; value: root.detail ? root.size(root.detail.ram.used) + " / " + root.size(root.detail.ram.total) : "–" },
        Field { name: "Swap"; value: root.detail ? root.size(root.detail.ram.swapUsed) + " / " + root.size(root.detail.ram.swapTotal) : "–" },
        Field { name: "Memory pressure"; value: root.detail ? root.pressureLevel(root.detail.ram.pressure) : "–" },
        Heading { text: "Top processes" },
        TopList { memory: true; model: root.detail ? root.detail.ram.top : [] }
      ]
    }

    Module {
      name: "ssd"
      BarText { text: "󰋊" }
      BarText { text: root.disk + "%"; Layout.minimumWidth: percentProbe.implicitWidth }

      popupContent: [
        Heading { text: root.detail && root.detail.disk.model ? root.detail.disk.model : "Disk"; Layout.topMargin: 0 },
        History {
          series: [
            { values: root.readHistory, color: root.downloadColor },
            { values: root.writeHistory, color: root.uploadColor }
          ]
        },
        Field { name: "Read"; dot: root.downloadColor; value: root.speed(root.diskRead) },
        Field { name: "Write"; dot: root.uploadColor; value: root.speed(root.diskWrite) },
        Heading { text: root.detail ? root.detail.disk.mount + "  (" + root.detail.disk.fstype + ")" : "Usage" },
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: Style.space(6)
          radius: height / 2
          color: root.idleColor
          Rectangle {
            width: parent.width * Math.min(1, root.disk / 100)
            height: parent.height
            radius: parent.radius
            color: root.accent
          }
        },
        Field { name: "Used"; value: root.detail ? root.size(root.detail.disk.used) + "  (" + root.disk + "%)" : root.disk + "%" },
        Field { name: "Free"; value: root.detail ? root.size(root.detail.disk.free) : "–" },
        Field { name: "Total"; value: root.detail ? root.size(root.detail.disk.total) : "–" },
        Heading { text: "Details" },
        Field { name: "Device"; value: root.detail ? root.detail.disk.device : "–" },
        Field { name: "Total read"; value: root.detail ? root.size(root.detail.disk.totalRead) : "–" },
        Field { name: "Total written"; value: root.detail ? root.size(root.detail.disk.totalWritten) : "–" }
      ]
    }
  }
}
