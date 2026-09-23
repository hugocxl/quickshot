import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ScreenshotError: LocalizedError {
    case displayUnavailable
    case imageUnavailable
    case outputUnavailable
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .displayUnavailable: "The active display could not be found."
        case .imageUnavailable: "macOS could not capture the display."
        case .outputUnavailable: "The Pictures folder is unavailable."
        case .writeFailed: "Quickshot could not save the screenshot."
        }
    }
}

struct ScreenshotService {
    private static let outputDirectoryName = "Quickshot"

    static func captureActiveDisplay() throws -> URL {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }),
              let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw ScreenshotError.displayUnavailable
        }
        guard let image = CGDisplayCreateImage(CGDirectDisplayID(displayNumber.uint32Value)) else {
            throw ScreenshotError.imageUnavailable
        }

        let directory = try outputDirectory()
        let fileURL = directory.appending(path: "Quickshot \(timestamp()).png")
        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ScreenshotError.writeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
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
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss.SSS"
        return formatter.string(from: .now)
    }
}
