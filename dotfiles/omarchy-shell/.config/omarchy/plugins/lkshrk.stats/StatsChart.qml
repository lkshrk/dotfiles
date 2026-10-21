import QtQuick

// "line": series = [{values: [...], color}] scaled to max (0 = auto). "donut": slices = [{value, color}].
Canvas {
  id: chart

  property string kind: "line"
  property var series: []
  property var slices: []
  property real max: 0
  property color grid: "#40707880"
  property int capacity: 60

  onSeriesChanged: requestPaint()
  onSlicesChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    if (kind === "donut") paintDonut(ctx)
    else paintLines(ctx)
  }

  function paintLines(ctx) {
    var top = max
    if (top <= 0) {
      for (var s = 0; s < series.length; s++)
        for (var i = 0; i < series[s].values.length; i++) top = Math.max(top, series[s].values[i])
      top = Math.max(1, top * 1.15)
    }

    ctx.strokeStyle = grid
    ctx.lineWidth = 1
    ctx.beginPath()
    for (var g = 1; g < 4; g++) {
      var gy = Math.round(height * g / 4) + 0.5
      ctx.moveTo(0, gy)
      ctx.lineTo(width, gy)
    }
    ctx.stroke()

    var step = width / Math.max(1, capacity - 1)
    for (var k = 0; k < series.length; k++) {
      var values = series[k].values
      if (values.length < 2) continue
      var x0 = width - (values.length - 1) * step
      ctx.beginPath()
      ctx.moveTo(x0, height)
      for (var j = 0; j < values.length; j++)
        ctx.lineTo(x0 + j * step, height - Math.min(1, values[j] / top) * height)
      ctx.lineTo(x0 + (values.length - 1) * step, height)
      ctx.closePath()
      ctx.fillStyle = Qt.rgba(series[k].color.r, series[k].color.g, series[k].color.b, 0.25)
      ctx.fill()

      ctx.beginPath()
      for (var m = 0; m < values.length; m++) {
        var y = height - Math.min(1, values[m] / top) * height
        if (m === 0) ctx.moveTo(x0, y)
        else ctx.lineTo(x0 + m * step, y)
      }
      ctx.strokeStyle = series[k].color
      ctx.lineWidth = 1.5
      ctx.stroke()
    }
  }

  function paintDonut(ctx) {
    var total = 0
    for (var i = 0; i < slices.length; i++) total += Math.max(0, slices[i].value)
    var r = Math.min(width, height) / 2 - 1
    var thickness = Math.max(4, r * 0.32)
    var cx = width / 2, cy = height / 2
    var start = -Math.PI / 2

    ctx.lineWidth = thickness
    if (total <= 0) {
      ctx.strokeStyle = grid
      ctx.beginPath()
      ctx.arc(cx, cy, r - thickness / 2, 0, Math.PI * 2)
      ctx.stroke()
      return
    }
    for (var s = 0; s < slices.length; s++) {
      var sweep = Math.max(0, slices[s].value) / total * Math.PI * 2
      if (sweep <= 0) continue
      ctx.strokeStyle = slices[s].color
      ctx.beginPath()
      ctx.arc(cx, cy, r - thickness / 2, start, start + sweep)
      ctx.stroke()
      start += sweep
    }
  }
}
