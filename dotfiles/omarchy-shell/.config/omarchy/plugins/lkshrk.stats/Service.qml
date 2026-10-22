import QtQuick
import Quickshell.Io

Item {
  id: root

  property var shell: null

  readonly property int interval: 2
  readonly property string diskMount: "/"
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

  property string publicIp: ""

  function pushed(list, value) {
    var next = list.slice(Math.max(0, list.length - historySize + 1))
    next.push(value)
    return next
  }

  Process {
    id: feed
    command: [root.pluginDir + "stats-feed", String(root.interval), root.diskMount]
    running: true
    onExited: restart.start()
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

  Timer {
    id: restart
    interval: 5000
    onTriggered: feed.running = true
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
  Component.onCompleted: refreshPublicIp()
}
