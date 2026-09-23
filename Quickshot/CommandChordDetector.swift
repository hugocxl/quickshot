/// Fires once when both Command keys are held. Release both to re-arm.
struct CommandChordDetector {
    private var blocked = false

    mutating func cancel() { blocked = true }

    /// Never interpret keys held across a listener interruption as a fresh shortcut.
    mutating func resynchronize(leftDown: Bool, rightDown: Bool) {
        blocked = leftDown || rightDown
    }

    mutating func update(leftDown: Bool, rightDown: Bool, otherModifierDown: Bool) -> Bool {
        if !leftDown && !rightDown {
            blocked = false
            return false
        }
        if otherModifierDown { blocked = true }
        guard leftDown && rightDown && !blocked else { return false }
        blocked = true
        return true
    }
}
