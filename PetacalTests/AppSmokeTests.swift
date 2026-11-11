import PetaCore
import Testing
@testable import Petacal

/// Checks that the app target links against PetaCore and that month navigation data is sane.
@Suite struct AppSmokeTests {
    @Test func monthRefIsComparable() {
        #expect(MonthRef(year: 2026, month: 11) == MonthRef(year: 2026, month: 11))
        #expect(MonthRef(year: 2026, month: 11) != MonthRef(year: 2026, month: 12))
    }

    @Test func coreIsLinked() {
        #expect(Yen.signed(5400) == "+5,400円")
    }
}
