import Foundation

public struct Ideal: Equatable {
	public let key: String
	public let value: String
	public init(key: String, value: String) {
		self.key = key
		self.value = value
	}
}

public final class Person {
	public var anxiety: Double
	public var happiness: Double
	public var contentment: Double
	public var ideals: [Ideal]

	public init(anxiety: Double, happiness: Double, contentment: Double, ideals: [Ideal]) {
		self.anxiety = anxiety
		self.happiness = happiness
		self.contentment = contentment
		self.ideals = ideals
	}
}

/// A “stressful event” exists outside Person and compares a target Ideal
/// against the person’s ideals, mutating their state.
public enum Stressor {
	/// Compares the provided ideal to the person’s set of ideals.
	/// If there’s a mismatch on the same key with a different value, it
	/// increases anxiety and decreases happiness by the given magnitudes.
	public static func apply(
		to person: Person,
		ideal: Ideal,
		anxietyDelta: Double = 5.0,
		happinessDelta: Double = 5.0,
		contentmentDelta: Double = 0.0
	) {
		let conflict = person.ideals.contains { $0.key == ideal.key && $0.value != ideal.value }
		if conflict {
			person.anxiety += anxietyDelta
			person.happiness = max(0, person.happiness - happinessDelta)
			person.contentment = max(0, person.contentment - contentmentDelta)
		}
	}
}