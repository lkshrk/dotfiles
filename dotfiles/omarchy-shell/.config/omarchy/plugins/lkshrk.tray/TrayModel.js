function text(value) {
  return String(value || "").toLowerCase()
}

function itemNamed(item, name) {
  if (!item) return false
  return text(item.id).indexOf(name) !== -1
    || text(item.title).indexOf(name) !== -1
    || text(item.tooltipTitle).indexOf(name) !== -1
}

// Wine names its items wine-0x<window>-<n>, which changes every launch; the title is stable.
function isBattleNet(item) {
  return !!item && text(item.id).indexOf("wine-") === 0 && text(item.title) === "battle.net"
}

// The games Battle.net's own tray menu lists, in its order; icons live in icons/<icon>.png.
var battleNetGames = [
  { text: "WoW: Forever", exec: "launch_uid wowf", icon: "wow" },
  { text: "World of Warcraft", exec: "launch WoW", icon: "wow" },
  { text: "Warcraft III", exec: "launch W3", icon: "warcraft-iii" },
  { text: "Diablo IV", exec: "launch Fen", icon: "diablo-iv" },
  { text: "Hearthstone", exec: "launch WTCG", icon: "hearthstone" }
]

function entryId(entry) {
  if (typeof entry === "string") return entry
  if (entry && typeof entry === "object") {
    var id = entry.id
    if (id !== undefined && id !== null && String(id) !== "") return String(id)
  }
  return ""
}

function layoutHasWidget(layout, id) {
  var sections = ["left", "center", "right"]
  for (var s = 0; s < sections.length; s++) {
    var entries = layout && layout[sections[s]]
    if (!Array.isArray(entries)) continue
    for (var i = 0; i < entries.length; i++) {
      if (entryId(entries[i]) === id) return true
    }
  }
  return false
}

// LocalSend's item shows no state, offers only Open and Quit, and its primary
// click is a no-op, so Share > Receive is the whole surface. Hiding it by hand
// doesn't stick either: LocalSend picks a fresh tray id every launch.
function ownedByOmarchy(item, layout) {
  return itemNamed(item, "localsend")
    || (layoutHasWidget(layout, "omarchy.dropbox") && itemNamed(item, "dropbox"))
}

if (typeof module !== "undefined") {
  module.exports = {
    itemNamed: itemNamed,
    entryId: entryId,
    layoutHasWidget: layoutHasWidget,
    ownedByOmarchy: ownedByOmarchy
  }
}
