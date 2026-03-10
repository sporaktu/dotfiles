import Cocoa
import CoreGraphics

let restingOffset = 5
let slideOffset = 35  // 24 (menu bar) + 5 (resting) + 6 (extra padding)
let triggerZone = 10
let exitZone = 50
let animFrames = 10

var state = "up"

func setOffset(_ offset: Int, frames: Int) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/local/bin/sketchybar")
    // Try homebrew path if default doesn't exist
    if !FileManager.default.fileExists(atPath: "/usr/local/bin/sketchybar") {
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar")
    }
    task.arguments = ["--animate", "sin", "\(frames)", "--bar", "y_offset=\(offset)"]
    try? task.run()
}

// Use a RunLoop-based timer for precise polling
let timer = Timer(timeInterval: 0.016, repeats: true) { _ in  // ~60fps
    let event = CGEvent(source: nil)
    guard let e = event else { return }
    let loc = e.location  // top-left origin, y=0 is top
    let y = Int(loc.y)

    if y <= triggerZone && state == "up" {
        setOffset(slideOffset, frames: 3)   // fast slide in
        state = "down"
    } else if y > exitZone && state == "down" {
        setOffset(restingOffset, frames: 10) // smooth slide out
        state = "up"
    }
}

RunLoop.main.add(timer, forMode: .common)
RunLoop.main.run()
