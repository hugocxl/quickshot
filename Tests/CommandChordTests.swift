@main
struct CommandChordTests {
    static func main() {
        var detector = CommandChordDetector()
        func keys(_ left: Bool, _ right: Bool, other: Bool = false) -> Bool {
            detector.update(leftDown: left, rightDown: right, otherModifierDown: other)
        }
        assert(!keys(true, false)); assert(keys(true, true)) // Left first
        assert(!keys(true, true)); assert(!keys(false, true))
        assert(!keys(true, true)) // Partial release does not re-arm
        assert(!keys(false, false))
        assert(!keys(false, true)); assert(keys(true, true)) // Right first
        assert(!keys(false, false))
        assert(!keys(true, false)); assert(!keys(false, false))
        assert(!keys(true, false)); assert(!keys(false, false)) // Double tap no longer fires
        assert(!keys(true, false)); detector.cancel() // Command-C
        assert(!keys(true, true)); assert(!keys(false, false))
        assert(!keys(true, true, other: true)); assert(!keys(true, true))
        assert(!keys(false, false)); assert(keys(true, true))
        print("PASS: both key orders, once per hold, full-release reset, no double tap, shortcut cancellation")
    }
}
