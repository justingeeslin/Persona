import XCTest
@testable import Persona

final class InterfaceUserTests: XCTestCase {

	func testDesktopUser_M_P_B_B_total() throws {
		// Desktop defaults: M=1.35, P=1.10, B=0.28
		let u = DesktopUser()
		let total = try u.taskTime(for: "M P B B")
		XCTAssertEqual(total, 1.35 + 1.10 + 0.28 + 0.28, accuracy: 1e-9)
	}

	func testWearableUser_G_T_T_M_total() throws {
		// Wearable defaults: G=0.50, T=0.25, M=1.35
		let u = WatchUser()
		let total = try u.taskTime(for: "G T T M")
		XCTAssertEqual(total, 0.50 + 0.25 + 0.25 + 1.35, accuracy: 1e-9)
	}

	func testSystemResponseToken_R_0_7() throws {
		let u = DesktopUser()
		let total = try u.taskTime(for: "M,R(0.7),K")
		XCTAssertEqual(total, 1.35 + 0.7 + 0.28, accuracy: 1e-9)
	}

	func testUnknownOperatorThrows() {
		let u = DesktopUser()
		XCTAssertThrowsError(try u.taskTime(for: "M Q K")) { err in
			XCTAssertEqual(err as? KLMError, .unknownOperator("Q"))
		}
	}

	func testMalformedResponseThrows() {
		let u = DesktopUser()
		XCTAssertThrowsError(try u.taskTime(for: "R(foo)")) { err in
			XCTAssertEqual(err as? KLMError, .malformedResponse("R(foo)"))
		}
	}

	func testTokenizationSpacesAndCommas() throws {
		let u = DesktopUser()
		// Using @testable to reach the internal helper
		let tokens = u.tokenize(" M,  P  ,B ,  R(0.5) ")
		XCTAssertEqual(tokens, ["M", "P", "B", "R(0.5)"])
	}

	func testBreakdownOrderAndValues() throws {
		let u = DesktopUser()
		let steps = try u.breakdown(for: "K R(0.50) P")
		// Expect exact order
		XCTAssertEqual(steps.map { $0.token }, ["K", "R(0.50)", "P"])
		// Check numeric values
		XCTAssertEqual(steps[0].seconds, 0.28, accuracy: 1e-9)
		XCTAssertEqual(steps[1].seconds, 0.50, accuracy: 1e-9)
		XCTAssertEqual(steps[2].seconds, 1.10, accuracy: 1e-9)
	}
	
	func testDesktopUser_FittsParameterizedP() throws {
		// ID = log2(D/W + 1) with D=2, W=4 => log2(1.5) ≈ 0.5849625
		// Desktop defaults: a=0.05, b=0.10 -> MT ≈ 0.05 + 0.10*0.5849625 = 0.10849625
		let u = DesktopUser()
		let total = try u.taskTime(for: "M P_distance:2;width:4 B")
		let expectedP = 0.05 + 0.10 * log2(2.0 / 4.0 + 1.0)
		let expected = 1.35 + expectedP + 0.28
		XCTAssertEqual(total, expected, accuracy: 1e-9)
	}
	
	func testPlainPStillUsesNominal() throws {
		let u = DesktopUser()
		let total = try u.taskTime(for: "P")
		XCTAssertEqual(total, 1.10, accuracy: 1e-9)
	}
	
	func testWearableUser_FittsParameterizedP_UsesWearableAB() throws {
		// Wearable defaults: a=0.10, b=0.20
		let u = WatchUser()
		let total = try u.taskTime(for: "P_distance:2;width:4")
		let expected = 0.10 + 0.20 * log2(2.0 / 4.0 + 1.0)
		XCTAssertEqual(total, expected, accuracy: 1e-9)
	}
	
	func testFittsMissingParamsThrows() {
		let u = DesktopUser()
		XCTAssertThrowsError(try u.taskTime(for: "P_distance:2")) { err in
			XCTAssertEqual(err as? KLMError, .missingFittsParams("P_distance:2"))
		}
		XCTAssertThrowsError(try u.taskTime(for: "P_width:3")) { err in
			XCTAssertEqual(err as? KLMError, .missingFittsParams("P_width:3"))
		}
	}
	
	func testFittsNonPositiveThrows() {
		let u = DesktopUser()
		XCTAssertThrowsError(try u.taskTime(for: "P_distance:0;width:2")) { err in
			XCTAssertEqual(err as? KLMError, .nonPositiveFittsParams("P_distance:0;width:2"))
		}
		XCTAssertThrowsError(try u.taskTime(for: "P_distance:2;width:0")) { err in
			XCTAssertEqual(err as? KLMError, .nonPositiveFittsParams("P_distance:2;width:0"))
		}
	}
	
	func testTokenizationAcceptsCommasSpacesForParameterizedP() throws {
		let u = DesktopUser()
		let tokens = u.tokenize(" M,  P_distance:2;width:4  ,B ")
		XCTAssertEqual(tokens, ["M", "P_distance:2;width:4", "B"])
	}
	
	func testBreakdownIncludesParameterizedPValue() throws {
		let u = DesktopUser()
		let steps = try u.breakdown(for: "K P_distance:2;width:4")
		XCTAssertEqual(steps.map { $0.token }, ["K", "P_distance:2;width:4"])
		// sanity check: P time within reasonable range
		XCTAssertTrue(steps[1].seconds > 0.05 && steps[1].seconds < 0.20)
	}
}