import Foundation

@main
struct ScreenshotStorageTests {
    static func main() throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appending(path: "QuickshotStorageTests-\(UUID().uuidString)")
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }

        let now = Date()
        let old = now.addingTimeInterval(-25 * 60 * 60)
        for (name, date) in [("Quickshot-expired.png", old), ("Quickshot-recent.png", now),
                             ("unrelated.png", old), ("Quickshot-note.txt", old)] {
            let file = directory.appending(path: name)
            try Data("test".utf8).write(to: file)
            try manager.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
        }
        let nested = directory.appending(path: "Quickshot-directory.png")
        try manager.createDirectory(at: nested, withIntermediateDirectories: true)
        try manager.setAttributes([.modificationDate: old], ofItemAtPath: nested.path)
        let link = directory.appending(path: "Quickshot-link.png")
        try manager.createSymbolicLink(at: link, withDestinationURL: directory.appending(path: "unrelated.png"))

        try ScreenshotService.cleanupTemporaryScreenshots(in: directory, now: now)
        let remaining = Set(try manager.contentsOfDirectory(atPath: directory.path))
        assert(remaining == ["Quickshot-recent.png", "unrelated.png", "Quickshot-note.txt",
                             "Quickshot-directory.png", "Quickshot-link.png"])
        try ScreenshotService.cleanupTemporaryScreenshots(in: directory.appending(path: "missing"), now: now)
        let desktop = try ScreenshotService.outputDirectory(for: .desktop)
        assert(desktop == manager.urls(for: .desktopDirectory, in: .userDomainMask).first!)
        assert(ScreenshotService.temporaryDirectory.deletingLastPathComponent().standardizedFileURL == manager.temporaryDirectory.standardizedFileURL)
        print("PASS: destination paths; expired temporary PNG cleanup preserves recent files, unrelated files, directories and symlinks")
    }
}
