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
        case .outputUnavailable: "The Pictures folder is unavailable."
        case .writeFailed: "Quickshot could not save the screenshot."
        }
    }
}

struct ScreenshotService {
    private static let outputDirectoryName = "Quickshot"

    @MainActor
    static func captureActiveDisplay() async throws -> URL {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }),
              let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw ScreenshotError.displayUnavailable
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayNumber.uint32Value }) else {
            throw ScreenshotError.displayUnavailable
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
        configuration.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)

        let directory = try outputDirectory()
        let fileURL = directory.appending(path: "Quickshot-\(timestamp())-\(UUID().uuidString).png")
        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ScreenshotError.writeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: fileURL)
            throw ScreenshotError.writeFailed
        }
        return fileURL
    }

    static func outputDirectory() throws -> URL {
        guard let picturesDirectory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first else {
            throw ScreenshotError.outputUnavailable
        }
        let outputDirectory = picturesDirectory.appending(path: outputDirectoryName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        return outputDirectory
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH.mm.ss.SSS"
        return formatter.string(from: .now)
    }
}
