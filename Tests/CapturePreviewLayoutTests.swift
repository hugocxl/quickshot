import Foundation
import CoreGraphics

@main
struct CapturePreviewLayoutTests {
    static func main() {
        let screens = [CGRect(x: 0, y: 0, width: 1512, height: 982),
                       CGRect(x: -1920, y: 0, width: 1920, height: 1080),
                       CGRect(x: 0, y: 982, width: 1080, height: 1920)]
        for screen in screens {
            let visible = screen.insetBy(dx: 0, dy: 40)
            let layout = CapturePreviewLayout(screen: screen, visible: visible, imageSize: screen.size)
            assert(visible.contains(layout.panel))
            assert(abs(layout.image.width / layout.image.height - screen.width / screen.height) < 0.001)
            assert(abs(layout.panel.maxX - (visible.maxX - 24)) < 0.001)
            assert(abs(layout.panel.minY - (visible.minY + 24)) < 0.001)
        }
        print("PASS: preview placement, aspect ratio, Dock margin, negative-origin and portrait displays")
    }
}
