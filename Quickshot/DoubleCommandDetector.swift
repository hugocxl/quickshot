/// Two isolated Command taps, completed within 0.4 seconds. Ordinary shortcuts cancel the gesture.
struct DoubleCommandDetector {
    private var commandDown = false
    private var pressTime: Double?
    private var firstTapTime: Double?

    mutating func cancel() {
        pressTime = nil
        firstTapTime = nil
    }

    mutating func update(commandDown: Bool, otherModifierDown: Bool, time: Double) -> Bool {
        defer { self.commandDown = commandDown }
        if otherModifierDown {
            cancel()
            return false
        }
        guard commandDown != self.commandDown else { return false }
        if commandDown {
            pressTime = time
            return false
        }
        guard let pressTime, time - pressTime <= 0.4 else {
            cancel()
            return false
        }
        self.pressTime = nil
        if let firstTapTime, time - firstTapTime <= 0.4 {
            self.firstTapTime = nil
            return true
        }
        firstTapTime = pressTime
        return false
    }
}
