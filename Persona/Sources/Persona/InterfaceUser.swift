import Foundation

// MARK: - Errors for KLM parsing/evaluation
public enum KLMError: Error, CustomStringConvertible, Equatable {
	case unknownOperator(String)
	case malformedResponse(String)

	public var description: String {
		switch self {
		case .unknownOperator(let tok):   return "Unknown operator: \(tok)"
		case .malformedResponse(let tok): return "Malformed response token: \(tok). Use R(0.5) style."
		}
	}
}

// MARK: - Base trait (protocol)
/// “Trait” for users that can evaluate a task time via KLM.
public protocol InterfaceUser {
	/// Per-operator times (seconds). Keys are compared uppercased.
	var klmOperatorTimes: [String: Double] { get }

	/// Public API: compute total time (seconds) for a sequence like "M P B B" or "K,P,R(0.7)".
	func taskTime(for actionString: String) throws -> Double
}

// MARK: - Default KLM implementation (desktop/mobile baseline)
public extension InterfaceUser {

	// Default operator timings (Card, Moran, Newell—tunable)
	// K: keystroke, P: point, H: homing, M: mental, B: button press
	var klmOperatorTimes: [String: Double] {
		[
			"K": 0.28,
			"P": 1.10,
			"H": 0.40,
			"M": 1.35,
			"B": 0.28
		]
	}

	// Public-facing API uses the internal helper.
	func taskTime(for actionString: String) throws -> Double {
		try breakdown(for: actionString).reduce(0) { $0 + $1.seconds }
	}

	// INTERNAL on purpose: helper not part of the protocol requirements.
	// With @testable imports, your tests can still exercise it;
	// external modules (without @testable) won’t see it.
	internal func breakdown(for actionString: String) throws -> [(token: String, seconds: Double)] {
		let tokens = tokenize(actionString)
		var out: [(String, Double)] = []

		for raw in tokens {
			// Support system response tokens like R(0.7)
			if raw.uppercased().hasPrefix("R(") && raw.hasSuffix(")") {
				let inner = raw.dropFirst(2).dropLast() // contents of (...)
				guard let secs = Double(String(inner)) else {
					throw KLMError.malformedResponse(raw)
				}
				out.append((raw, secs))
				continue
			}

			// Normal operator
			let key = raw.uppercased()
			if let secs = klmOperatorTimes[key] {
				out.append((key, secs))
			} else {
				throw KLMError.unknownOperator(raw)
			}
		}

		return out
	}

	// Flexible splitter: spaces and/or commas, ignores empties
	internal func tokenize(_ s: String) -> [String] {
		s.split(whereSeparator: { $0 == " " || $0 == "," })
		 .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
		 .filter { !$0.isEmpty }
	}
}

// MARK: - Derived trait (protocol) for wearables
public protocol WearableInterfaceUser: InterfaceUser {}

// Wearable defaults: tweak to your population/device
public extension WearableInterfaceUser {
	var klmOperatorTimes: [String: Double] {
		[
			"M": 1.35,  // mental prep
			"T": 0.25,  // tap
			"S": 0.40,  // swipe
			"G": 0.50,  // glance / raise-to-view
			"P": 0.80,  // coarse pointing/aiming
			"B": 0.20,  // hardware button press
			"H": 0.40   // homing
		]
	}
}

// MARK: - Example conformers you can use directly

public struct DesktopUser: InterfaceUser { /* uses default map */ }

public struct WatchUser: WearableInterfaceUser { /* uses wearable map */ }