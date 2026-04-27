import Cocoa

/// Force displays to sleep via sudo pmset (requires sudoers entry).
func sleepDisplay() {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    task.arguments = ["/usr/bin/pmset", "displaysleepnow"]
    do {
        try task.run()
        task.waitUntilExit()
        fputs("sleep-on-lock: display sleep triggered\n", stderr)
    } catch {
        fputs("sleep-on-lock: pmset failed — \(error)\n", stderr)
    }
}

if CommandLine.arguments.contains("--daemon") {
    // Watch for screen lock and sleep displays after a short delay
    let center = DistributedNotificationCenter.default()
    center.addObserver(
        forName: NSNotification.Name("com.apple.screenIsLocked"),
        object: nil,
        queue: .main
    ) { _ in
        fputs("sleep-on-lock: lock detected, sleeping in 2s\n", stderr)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            sleepDisplay()
        }
    }
    fputs("sleep-on-lock: daemon started, watching for lock events\n", stderr)
    RunLoop.main.run()
} else {
    // One-shot: sleep display immediately
    sleepDisplay()
}
