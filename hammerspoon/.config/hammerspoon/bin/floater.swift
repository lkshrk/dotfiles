import Foundation
import CoreGraphics

@_silgen_name("SLSMainConnectionID")
func SLSMainConnectionID() -> Int32

@_silgen_name("SLSSetWindowLevel")
func SLSSetWindowLevel(_ cid: Int32, _ wid: UInt32, _ level: Int32) -> Int32

@_silgen_name("SLSGetWindowLevel")
func SLSGetWindowLevel(_ cid: Int32, _ wid: UInt32, _ level: UnsafeMutablePointer<Int32>) -> Int32

@_silgen_name("SLSSetWindowSubLevel")
func SLSSetWindowSubLevel(_ cid: Int32, _ wid: UInt32, _ subLevel: Int32) -> Int32

@_silgen_name("SLSGetWindowSubLevel")
func SLSGetWindowSubLevel(_ cid: Int32, _ wid: UInt32, _ subLevel: UnsafeMutablePointer<Int32>) -> Int32

@_silgen_name("SLSOrderWindow")
func SLSOrderWindow(_ cid: Int32, _ wid: UInt32, _ mode: Int32, _ relativeTo: UInt32) -> Int32

@_silgen_name("SLSSetWindowTags")
func SLSSetWindowTags(_ cid: Int32, _ wid: UInt32, _ tags: UnsafePointer<UInt32>, _ nBits: Int32) -> Int32

@_silgen_name("SLSGetWindowTags")
func SLSGetWindowTags(_ cid: Int32, _ wid: UInt32, _ tags: UnsafeMutablePointer<UInt32>, _ nBits: Int32) -> Int32

func usage() -> Never {
    let msg = """
    usage: floater <cmd> [args...]
      list                       enumerate visible app windows
      get <wid>                  print current level
      set <wid> <level>          SLSSetWindowLevel
      subget <wid>               SLSGetWindowSubLevel
      subset <wid> <sublevel>    SLSSetWindowSubLevel
      order <wid> <mode>         SLSOrderWindow (mode: 1=above, -1=below, 0=out)
      tagget <wid>               SLSGetWindowTags (32 bits)
      tagset <wid> <hex>         SLSSetWindowTags (hex value, 32 bits)
      probe <wid>                run all get-* checks and print summary
    """
    FileHandle.standardError.write(Data((msg + "\n").utf8))
    exit(1)
}

let args = CommandLine.arguments
let cid = SLSMainConnectionID()

guard args.count >= 2 else { usage() }

switch args[1] {
case "list":
    let opts = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
    let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] ?? []
    for w in info {
        let layer = w[kCGWindowLayer as String] as? Int ?? 0
        if layer != 0 { continue }
        let wid = w[kCGWindowNumber as String] as? Int ?? 0
        let owner = w[kCGWindowOwnerName as String] as? String ?? ""
        let name = w[kCGWindowName as String] as? String ?? ""
        print("\(wid)\t\(owner)\t\(name)")
    }

case "get":
    guard args.count == 3, let wid = UInt32(args[2]) else { usage() }
    var lvl: Int32 = 0
    let e = SLSGetWindowLevel(cid, wid, &lvl)
    print("err=\(e) level=\(lvl)")

case "set":
    guard args.count == 4, let wid = UInt32(args[2]), let lvl = Int32(args[3]) else { usage() }
    let e = SLSSetWindowLevel(cid, wid, lvl)
    print("err=\(e)")

case "subget":
    guard args.count == 3, let wid = UInt32(args[2]) else { usage() }
    var s: Int32 = 0
    let e = SLSGetWindowSubLevel(cid, wid, &s)
    print("err=\(e) sublevel=\(s)")

case "subset":
    guard args.count == 4, let wid = UInt32(args[2]), let s = Int32(args[3]) else { usage() }
    let e = SLSSetWindowSubLevel(cid, wid, s)
    print("err=\(e)")

case "order":
    guard args.count == 4, let wid = UInt32(args[2]), let m = Int32(args[3]) else { usage() }
    let e = SLSOrderWindow(cid, wid, m, 0)
    print("err=\(e)")

case "tagget":
    guard args.count == 3, let wid = UInt32(args[2]) else { usage() }
    var tags: UInt32 = 0
    let e = SLSGetWindowTags(cid, wid, &tags, 32)
    print(String(format: "err=%d tags=0x%08x", e, tags))

case "tagset":
    guard args.count == 4, let wid = UInt32(args[2]) else { usage() }
    let hex = args[3].hasPrefix("0x") ? String(args[3].dropFirst(2)) : args[3]
    guard let val = UInt32(hex, radix: 16) else { usage() }
    var tags: UInt32 = val
    let e = SLSSetWindowTags(cid, wid, &tags, 32)
    print(String(format: "err=%d wrote=0x%08x", e, val))

case "probe":
    guard args.count == 3, let wid = UInt32(args[2]) else { usage() }
    var lvl: Int32 = 0
    var sub: Int32 = 0
    var tags: UInt32 = 0
    let e1 = SLSGetWindowLevel(cid, wid, &lvl)
    let e2 = SLSGetWindowSubLevel(cid, wid, &sub)
    let e3 = SLSGetWindowTags(cid, wid, &tags, 32)
    print("level:    err=\(e1) value=\(lvl)")
    print("sublevel: err=\(e2) value=\(sub)")
    print(String(format: "tags:     err=%d value=0x%08x", e3, tags))

default:
    usage()
}
