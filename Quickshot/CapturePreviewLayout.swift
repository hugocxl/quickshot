import CoreGraphics

struct CapturePreviewLayout {
    let panel: CGRect
    var image: CGRect { panel }

    init(screen: CGRect, visible: CGRect, imageSize: CGSize) {
        let usable = visible.intersection(screen)
        let margin: CGFloat = 24
        let maxWidth = min(300, max(120, usable.width * 0.23))
        let maxHeight = min(200, max(80, usable.height - 2 * margin))
        let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        panel = CGRect(x: usable.maxX - margin - size.width, y: usable.minY + margin,
                       width: size.width, height: size.height)
    }
}
