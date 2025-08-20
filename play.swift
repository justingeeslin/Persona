import Foundation

// MARK: - Domain Types

/// A simple "trait-like" value: an ideal with a key, a numeric target value, and an importance weight.
/// Use value in [0, 1] to represent the target intensity; weight in [0, 1] for importance.
struct Ideal: Equatable {
	let key: String
	let value: Double   // 0.0 ... 1.0
	let weight: Double  // 0.0 ... 1.0
}

/// Person is a reference type (class) so outside processes can mutate it.
class Person {
	var anxiety: Int        // 0...100
	var happiness: Int      // 0...100
	var contentment: Int    // 0...100
	var ideals: [Ideal]     // Person's internalized ideals

	init(anxiety: Int, happiness: Int, contentment: Int, ideals: [Ideal]) {
		self.anxiety = anxiety
		self.happiness = happiness
		self.contentment = contentment
		self.ideals = ideals
	}
}

// MARK: - Utilities

@inline(__always)
func clamp(_ x: Int, _ lo: Int = 0, _ hi: Int = 100) -> Int { max(lo, min(hi, x)) }

// MARK: - Stress process (outside of Person)

/// A trait-like protocol for mapping mismatch -> emotional deltas.
/// Return positive/negative deltas; the caller applies and clamps.
protocol StressProcess {
	func deltas(for mismatch: Double, weight: Double) -> (dAnxiety: Int, dHappiness: Int, dContentment: Int)
}

/// A default stress model: linear in mismatch and weight, scaled to sensible UI-sized steps.
struct DefaultStressProcess: StressProcess {
	/// `mismatch` ∈ [0,1], `weight` ∈ [0,1].
	/// Tune the scale constants to your domain.
	func deltas(for mismatch: Double, weight: Double) -> (dAnxiety: Int, dHappiness: Int, dContentment: Int) {
		let scale = 20.0 // max size of a single event’s impact
		let impact = mismatch * weight * scale
		// Anxiety increases; happiness and contentment decrease.
		return (dAnxiety: Int(round(+impact)),
				dHappiness: Int(round(-impact * 0.6)),
				dContentment: Int(round(-impact * 0.4)))
	}
}

/// Applies a stressful event by comparing an external ideal to the person's corresponding ideal (same key).
/// If no matching ideal exists, we treat it as low impact novelty.
func applyStress(from externalIdeal: Ideal,
				 to person: Person,
				 using process: StressProcess = DefaultStressProcess())
{
	// Find a matching ideal by key.
	if let own = person.ideals.first(where: { $0.key == externalIdeal.key }) {
		// Mismatch is absolute distance between values (both in [0,1]).
		let mismatch = abs(externalIdeal.value - own.value)
		let weight   = max(own.weight, externalIdeal.weight) // conservative: stronger of the two
		let (dA, dH, dC) = process.deltas(for: mismatch, weight: weight)
		person.anxiety     = clamp(person.anxiety + dA)
		person.happiness   = clamp(person.happiness + dH)
		person.contentment = clamp(person.contentment + dC)
	} else {
		// No internal reference: small generic jolt.
		let (dA, dH, dC) = process.deltas(for: 0.25, weight: externalIdeal.weight * 0.5)
		person.anxiety     = clamp(person.anxiety + dA)
		person.happiness   = clamp(person.happiness + dH)
		person.contentment = clamp(person.contentment + dC)
	}
}

// MARK: - Example

let bodyIdeal    = Ideal(key: "body_image", value: 0.3, weight: 0.8)  // person’s gentler stance
let careerIdeal  = Ideal(key: "career_status", value: 0.5, weight: 0.6)

let p = Person(anxiety: 20, happiness: 70, contentment: 55, ideals: [bodyIdeal, careerIdeal])

print("Before  -> A:\(p.anxiety) H:\(p.happiness) C:\(p.contentment)")

// External societal ideal (e.g., media message) that is stricter on body image
let external = Ideal(key: "body_image", value: 0.9, weight: 0.9)

applyStress(from: external, to: p)

print("After   -> A:\(p.anxiety) H:\(p.happiness) C:\(p.contentment)")