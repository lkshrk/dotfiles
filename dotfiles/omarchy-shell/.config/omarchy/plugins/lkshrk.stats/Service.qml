import QtQuick
import Quickshell.Io

Item {
  id: root

  property var shell: null

  readonly property int interval: 2
  readonly property string diskMount: "/"
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

  property string diskDevice: ""
  property var prev: null

  function pushed(list, value) {
    var next = list.slice(Math.max(0, list.length - historySize + 1))
    next.push(value)
    return next
  }

  function read(view) {
    view.reload()
    return view.loaded ? view.text() : ""
  }

  function cpuSample(text) {
    var m = text.match(/^cpu\s+(.*)$/m)
    if (!m) return null
    var f = m[1].trim().split(/\s+/).map(Number)
    return {
      user: f[0] + f[1],
      sys: f[2] + f[5] + f[6],
      idle: f[3] + f[4],
      total: f[0] + f[1] + f[2] + f[3] + f[4] + f[5] + f[6] + f[7]
    }
  }

  function ramPercent(text) {
    var t = text.match(/^MemTotal:\s+(\d+)/m)
    var a = text.match(/^MemAvailable:\s+(\d+)/m)
    if (!t || !a || Number(t[1]) <= 0) return null
    return Math.round(100 * (Number(t[1]) - Number(a[1])) / Number(t[1]))
  }

  function netSample(text) {
    if (text === "") return null
    var rx = 0, tx = 0
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var colon = lines[i].indexOf(":")
      if (colon < 0) continue
      var name = lines[i].slice(0, colon).trim()
      if (/^(lo|docker.*|veth.*|br-.*|virbr.*|tailscale.*)$/.test(name)) continue
      var f = lines[i].slice(colon + 1).trim().split(/\s+/).map(Number)
      rx += f[0]
      tx += f[8]
    }
    return { rx: rx, tx: tx }
  }

  function diskSample(text) {
    if (text === "" || diskDevice === "") return null
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/)
      if (f[2] === diskDevice) return { read: Number(f[5]) * 512, write: Number(f[9]) * 512 }
    }
    return null
  }

  function rate(now, before) {
    return now !== null && before !== null ? Math.max(0, Math.round((now - before) / interval)) : 0
  }

  function sample() {
    var c = cpuSample(read(statFile))
    var r = ramPercent(read(meminfoFile))
    var n = netSample(read(netFile))
    var d = diskSample(read(diskstatsFile))
    var cur = {
      cpu: c,
      rx: n ? n.rx : null, tx: n ? n.tx : null,
      dr: d ? d.read : null, dw: d ? d.write : null
    }
    var p = prev
    prev = cur
    if (p === null) return

    var dt = c && p.cpu ? c.total - p.cpu.total : 0
    if (dt > 0) {
      cpu = Math.round(100 * (dt - (c.idle - p.cpu.idle)) / dt)
      cpuUser = Math.round(100 * (c.user - p.cpu.user) / dt)
      cpuSystem = Math.round(100 * (c.sys - p.cpu.sys) / dt)
    } else {
      cpu = 0; cpuUser = 0; cpuSystem = 0
    }
    if (r !== null) ram = r
    rx = rate(cur.rx, p.rx)
    tx = rate(cur.tx, p.tx)
    diskRead = rate(cur.dr, p.dr)
    diskWrite = rate(cur.dw, p.dw)

    cpuHistory = pushed(cpuHistory, cpu)
    ramHistory = pushed(ramHistory, ram)
    rxHistory = pushed(rxHistory, rx)
    txHistory = pushed(txHistory, tx)
    readHistory = pushed(readHistory, diskRead)
    writeHistory = pushed(writeHistory, diskWrite)
  }

  FileView { id: statFile; path: "/proc/stat"; blockLoading: true; printErrors: false }
  FileView { id: meminfoFile; path: "/proc/meminfo"; blockLoading: true; printErrors: false }
  FileView { id: netFile; path: "/proc/net/dev"; blockLoading: true; printErrors: false }
  FileView { id: diskstatsFile; path: "/proc/diskstats"; blockLoading: true; printErrors: false }

  Timer {
    interval: root.interval * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.sample()
  }

  Process {
    command: [Qt.resolvedUrl("stats-detail").toString().replace("file://", ""), "--device", root.diskMount]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.diskDevice = String(text).trim()
    }
  }

  Process {
    id: dfProc
    command: ["df", "-P", root.diskMount]
    stdout: StdioCollector {
      onStreamFinished: {
        var m = String(text).match(/\s(\d+)%\s/)
        if (m) root.disk = Number(m[1])
      }
    }
  }

  Timer {
    interval: 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!dfProc.running) dfProc.running = true
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
