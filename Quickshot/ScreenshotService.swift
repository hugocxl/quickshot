import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ScreenCaptureKit

enum ScreenshotError: LocalizedError {
    case displayUnavailable
    case outputUnavailable
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .displayUnavailable: "The active display could not be found."
        case .outputUnavailable: "The selected screenshots folder is unavailable."
        case .writeFailed: "Quickshot could not save the screenshot."
        }
    }
}

enum SaveDestination: String, CaseIterable {
    case desktop
    case temporary

    var title: String {
        switch self {
        case .desktop: "Desktop"
        case .temporary: "tmp (auto-delete after 24 hours)"
        }
    }

    static var selected: SaveDestination {
        get { SaveDestination(rawValue: UserDefaults.standard.string(forKey: "saveDestination") ?? "") ?? .desktop }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "saveDestination") }
    }
}

struct ScreenshotService {
    static var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory.appending(path: "Quickshot", directoryHint: .isDirectory)
    }

    @MainActor
    static func captureActiveDisplay() async throws -> (url: URL, screen: NSScreen, image: CGImage) {
        let saveDestination = SaveDestination.selected
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }),
              let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw ScreenshotError.displayUnavailable
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayNumber.uint32Value }) else {
            throw ScreenshotError.displayUnavailable
        }
        let ownApplication = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApplication, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
        configuration.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)

        let directory = try outputDirectory(for: saveDestination)
        let fileURL = directory.appending(path: "Quickshot-\(timestamp())-\(UUID().uuidString).png")
        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ScreenshotError.writeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: fileURL)
            throw ScreenshotError.writeFailed
        }
        return (fileURL, screen, image)
    }

    static func outputDirectory(for destination: SaveDestination = .selected) throws -> URL {
        let outputDirectory: URL
        switch destination {
        case .desktop:
            guard let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
                throw ScreenshotError.outputUnavailable
            }
            outputDirectory = desktop
        case .temporary:
            outputDirectory = temporaryDirectory
        }
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        return outputDirectory
    }

    // Only expire our own PNGs, never other contents of the macOS temporary folder.
    static func cleanupTemporaryScreenshots(in directory: URL = temporaryDirectory, now: Date = .now) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: directory.path) else { return }
        let files = try manager.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)
        for file in files where file.lastPathComponent.hasPrefix("Quickshot-") && file.pathExtension == "png" {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate, modified <= cutoff else { continue }
            try manager.removeItem(at: file)
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH.mm.ss.SSS"
        return formatter.string(from: .now)
    }
}
