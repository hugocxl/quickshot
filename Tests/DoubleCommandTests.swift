@main
struct DoubleCommandTests {
    static func main() {
        var detector = DoubleCommandDetector()
        func flags(_ down: Bool, _ time: Double, other: Bool = false) -> Bool {
            detector.update(commandDown: down, otherModifierDown: other, time: time)
        }
        assert(!flags(true, 0)); assert(!flags(false, 0.05))
        assert(!flags(true, 0.15)); assert(flags(false, 0.2))
        assert(!flags(true, 1)); assert(!flags(false, 1.1))
        assert(!flags(true, 2)); assert(!flags(false, 2.1)) // Too slow
        detector = DoubleCommandDetector()
        assert(!flags(true, 3)); detector.cancel() // Command-C
        assert(!flags(false, 3.05)); assert(!flags(true, 3.1)); assert(!flags(false, 3.15))
        detector = DoubleCommandDetector()
        assert(!flags(true, 4)); assert(!flags(false, 4.05))
        assert(!flags(true, 4.1, other: true)); assert(!flags(false, 4.15))
        detector = DoubleCommandDetector()
        assert(!flags(true, 5)); assert(!flags(true, 5.1)); assert(!flags(false, 6)) // Hold
        assert(!flags(true, 6.1)); assert(!flags(false, 6.15))
        print("PASS: double tap, timeout, ordinary shortcut, modified gesture, held key")
    }
}
