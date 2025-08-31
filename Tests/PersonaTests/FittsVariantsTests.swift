import XCTest
@testable import Persona

final class FittsVariantsTests: XCTestCase {

	// D=120, W=12 -> D/W = 10
	// Shannon/Welford: ID = log2(10 + 1) = log2(11) ≈ 3.4594316
	// Original Fitts:  ID = log2(2*10)   = log2(20) ≈ 4.3219281

	let D: Double = 120
	let W: Double = 12
	let shannonID = log2(11.0)
	let originalID = log2(20.0)

	func testDesktopShannonParameterizedP() throws {
		let u = DesktopShannonUser()
		let total = try u.taskTime(for: "M P_distance:120;width:12 B")
		let expectedP = 1.03 + 0.096 * shannonID
		let expected = 1.2 + expectedP + 0.1
		XCTAssertEqual(total, expected, accuracy: 1e-9)
	}

	func testDesktopOriginalFittsParameterizedP() throws {
		let u = DesktopOriginalFittsUser() 
		let total = try u.taskTime(for: "M P_distance:120;width:12 B")
		let expectedP = 1.03 + 0.096 * originalID
		let expected = 1.2 + expectedP + 0.1
		XCTAssertEqual(total, expected, accuracy: 1e-9)
	}

	func testDesktopWelfordMatchesShannon() throws {
		let sh = DesktopShannonUser()
		let wf = DesktopWelfordUser()
		let a = try sh.taskTime(for: "P_distance:120;width:12")
		let b = try wf.taskTime(for: "P_distance:120;width:12")
		XCTAssertEqual(a, b, accuracy: 1e-12) // algebraically identical
	}

	func testPlainPFallbackUnaffected() throws {
		// Still uses klmOperatorTimes["P"], not Fitts
		let u = DesktopOriginalFittsUser()
		let total = try u.taskTime(for: "P")
		XCTAssertEqual(total, 1.10, accuracy: 1e-9)
	}

	func testBadFittsParamsStillThrow() {
		let u = DesktopWelfordUser()
		XCTAssertThrowsError(try u.taskTime(for: "P_distance:0;width:12")) { err in
			XCTAssertEqual(err as? KLMError, .nonPositiveFittsParams("P_distance:0;width:12"))
		}
		XCTAssertThrowsError(try u.taskTime(for: "P_distance:120")) { err in
			XCTAssertEqual(err as? KLMError, .missingFittsParams("P_distance:120"))
		}
	}
}
