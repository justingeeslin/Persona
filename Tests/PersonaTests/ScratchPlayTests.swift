import XCTest
@testable import Persona   // <- lets tests access internal symbols

final class ScratchPlayTests: XCTestCase {
	func testPlay() throws {
		// If WatchUser has internal init(), this still works here
		let u = WatchUser()

		// Try whatever you want:
		let total = try u.taskTime(for: "P_distance:15;width:3")
		print("Total Pointing time = ", total)

		// Optional quick check
		// If you need log2:
		let expected = 0.10 + 0.20 * log2(2.0 / 4.0 + 1.0)
		XCTAssertEqual(total, expected, accuracy: 1e-9)
	}
}