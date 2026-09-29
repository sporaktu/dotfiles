import Cocoa
import CoreGraphics

let restingOffset = 5
let slideOffset = 35  // 24 (menu bar) + 5 (resting) + 6 (extra padding)
let triggerZone = 10
let exitZone = 50

let yabaiPath = "/opt/homebrew/bin/yabai"
let sketchybarPath = FileManager.default.fileExists(atPath: "/usr/local/bin/sketchybar")
    ? "/usr/local/bin/sketchybar"
    : "/opt/homebrew/bin/sketchybar"

// Read base top padding from yabai config (default 10)
let baseTopPadding = 10
let menuBarPadding = 30  // extra padding when menu bar is visible

var state = "up"

func runAsync(_ path: String, _ args: [String]) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: path)
    task.arguments = args
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try? task.run()
}

func slideDown() {
    // Move sketchybar down. Deliberately NOT animated: sketchybar's animator
    // deadlocks against a concurrent display-reconfiguration event (its
    // CVDisplayLink is released from inside its own frame callback), which
    // wedges the daemon into a live-but-unresponsive state.
    runAsync(sketchybarPath, ["--bar", "y_offset=\(slideOffset)"])
    // Increase yabai top padding for all spaces
    runAsync(yabaiPath, ["-m", "config", "top_padding", "\(baseTopPadding + menuBarPadding)"])
}

func slideUp() {
    // Move sketchybar back up. Unanimated for the same reason as slideDown().
    runAsync(sketchybarPath, ["--bar", "y_offset=\(restingOffset)"])
    // Restore yabai top padding
    runAsync(yabaiPath, ["-m", "config", "top_padding", "\(baseTopPadding)"])
}

// Poll cursor position at ~60fps
let timer = Timer(timeInterval: 0.016, repeats: true) { _ in
    let event = CGEvent(source: nil)
    guard let e = event else { return }
    let y = Int(e.location.y)  // top-left origin, y=0 is top

    if y <= triggerZone && state == "up" {
        slideDown()
        state = "down"
    } else if y > exitZone && state == "down" {
        slideUp()
        state = "up"
    }
}

RunLoop.main.add(timer, forMode: .common)
RunLoop.main.run()
