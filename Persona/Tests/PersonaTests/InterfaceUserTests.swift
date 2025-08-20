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
}