import Foundation

let notificationName = NSNotification.Name("com.apple.screenIsLocked")
let center = DistributedNotificationCenter.default()

print("sleep-on-lock: daemon started, watching for lock events")

let observer = center.addObserver(
  forName: notificationName,
  object: nil,
  queue: .main
) { _ in
  print("sleep-on-lock: lock detected, sleeping in 2s")

  DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["displaysleepnow"]

    do {
      try process.run()
      process.waitUntilExit()

      if process.terminationStatus == 0 {
        print("sleep-on-lock: display sleep triggered")
      } else {
        print("sleep-on-lock: pmset failed \(process.terminationStatus)")
      }
    } catch {
      print("sleep-on-lock: pmset failed \(error.localizedDescription)")
    }
  }
}

defer {
  center.removeObserver(observer)
}

RunLoop.main.run()
