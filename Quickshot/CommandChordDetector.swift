/// Fires once when both Command keys are held. Release both to re-arm.
struct CommandChordDetector {
    private var blocked = false

    mutating func cancel() { blocked = true }

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
