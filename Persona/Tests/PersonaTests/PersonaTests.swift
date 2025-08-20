import XCTest
@testable import Persona

final class PersonaTests: XCTestCase {

	func testStressorDoesNothingWhenNoConflict() {
		let p = Person(
			anxiety: 10, happiness: 80, contentment: 70,
			ideals: [Ideal(key: "career", value: "academia"),
					 Ideal(key: "appearance", value: "androgynous")]
		)

		// Ideal aligns with an existing one → no conflict
		Stressor.apply(to: p, ideal: Ideal(key: "appearance", value: "androgynous"))

		XCTAssertEqual(p.anxiety, 10, accuracy: 1e-9)
		XCTAssertEqual(p.happiness, 80, accuracy: 1e-9)
		XCTAssertEqual(p.contentment, 70, accuracy: 1e-9)
	}

	func testStressorIncreasesAnxietyAndDecreasesHappinessOnConflict() {
		let p = Person(
			anxiety: 10, happiness: 80, contentment: 70,
			ideals: [Ideal(key: "appearance", value: "androgynous")]
		)

		// Conflict on same key, different value
		Stressor.apply(
			to: p,
			ideal: Ideal(key: "appearance", value: "strictly_masculine"),
			anxietyDelta: 7.5,
			happinessDelta: 12.0,
			contentmentDelta: 3.0
		)

		XCTAssertEqual(p.anxiety, 17.5, accuracy: 1e-9)
		XCTAssertEqual(p.happiness, 68.0, accuracy: 1e-9)
		XCTAssertEqual(p.contentment, 67.0, accuracy: 1e-9)
	}

	func testMultipleConflictsCanAccumulate() {
		let p = Person(
			anxiety: 0, happiness: 100, contentment: 100,
			ideals: [
				Ideal(key: "appearance", value: "androgynous"),
				Ideal(key: "career", value: "academia")
			]
		)

		Stressor.apply(to: p, ideal: Ideal(key: "appearance", value: "strictly_masculine"), anxietyDelta: 4, happinessDelta: 5)
		Stressor.apply(to: p, ideal: Ideal(key: "career", value: "corporate"), anxietyDelta: 6, happinessDelta: 7)

		XCTAssertEqual(p.anxiety, 10, accuracy: 1e-9)     // 4 + 6
		XCTAssertEqual(p.happiness, 88, accuracy: 1e-9)   // 100 - 5 - 7
	}

	func testHappinessAndContentmentNotBelowZero() {
		let p = Person(
			anxiety: 20, happiness: 3, contentment: 2,
			ideals: [Ideal(key: "appearance", value: "androgynous")]
		)

		Stressor.apply(
			to: p,
			ideal: Ideal(key: "appearance", value: "strictly_masculine"),
			anxietyDelta: 10, happinessDelta: 10, contentmentDelta: 5
		)

		XCTAssertEqual(p.happiness, 0, accuracy: 1e-9)
		XCTAssertEqual(p.contentment, 0, accuracy: 1e-9)
		XCTAssertEqual(p.anxiety, 30, accuracy: 1e-9)
	}

	func testIdealEquatability() {
		let a = Ideal(key: "appearance", value: "androgynous")
		let b = Ideal(key: "appearance", value: "androgynous")
		let c = Ideal(key: "appearance", value: "strictly_masculine")

		XCTAssertEqual(a, b)
		XCTAssertNotEqual(a, c)
	}
}