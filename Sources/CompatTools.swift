import Foundation

struct CompatTool: Identifiable, Equatable {
    let id: String
    let name: String
    let tip: String
    let path: String?
    var installed: Bool { path != nil }
}

enum CompatTools {
    static func detect() -> [CompatTool] {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let dirs = [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications"),
        ]
        func find(_ names: [String]) -> String? {
            for dir in dirs {
                for n in names {
                    let p = dir.appendingPathComponent(n)
                    if FileManager.default.fileExists(atPath: p.path) { return p.path }
                }
            }
            return nil
        }
        // GPTK is often a CLI / developer package — check common markers
        let gptkMarkers = [
            "/usr/local/bin/gameportingtoolkit",
            "/opt/homebrew/bin/gameportingtoolkit",
            "\(NSHomeDirectory())/Library/Application Support/Game Porting Toolkit",
        ]
        let gptkPath = gptkMarkers.first { FileManager.default.fileExists(atPath: $0) }

        return [
            CompatTool(
                id: "crossover",
                name: "CrossOver",
                tip: "Paid Wine build. Good for many Windows Steam/Epic titles when a Mac build is missing.",
                path: find(["CrossOver.app"])
            ),
            CompatTool(
                id: "whisky",
                name: "Whisky",
                tip: "Unmaintained GPTK wrapper. Leave if a bottle already works; prefer Heroic runners or CrossOver for new setups.",
                path: find(["Whisky.app"])
            ),
            CompatTool(
                id: "gptk",
                name: "Game Porting Toolkit",
                tip: "Apple’s compatibility layer (CLI). Heroic can use GPTK/Wine runners for Windows games.",
                path: gptkPath
            ),
        ]
    }
}
