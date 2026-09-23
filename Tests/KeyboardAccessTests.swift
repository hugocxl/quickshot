@main
struct KeyboardAccessTests {
    static func main() {
        typealias Status = HotKeyManager.RegistrationStatus
        // Regression: a tap that works while Quickshot is frontmost must not be labeled global-ready.
        assert(Status.evaluate(inputAllowed: false, tapEnabled: true, secureInput: false) == .permissionDenied)
        assert(Status.evaluate(inputAllowed: false, tapEnabled: false, secureInput: false) == .permissionDenied)
        assert(Status.evaluate(inputAllowed: true, tapEnabled: false, secureInput: false) == .tapUnavailable)
        assert(Status.evaluate(inputAllowed: true, tapEnabled: true, secureInput: true) == .secureInput)
        assert(Status.evaluate(inputAllowed: true, tapEnabled: true, secureInput: false) == .ready)
        assert(Status.evaluate(inputAllowed: false, tapEnabled: true, secureInput: true) == .permissionDenied)
        print("PASS: foreground-only tap rejected, revoked grant, disabled tap, secure input, global readiness")
    }
}
