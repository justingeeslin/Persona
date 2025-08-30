import Foundation

// MARK: - Errors for KLM parsing/evaluation
public enum KLMError: Error, CustomStringConvertible, Equatable {
	case unknownOperator(String)
	case malformedResponse(String)
	case missingFittsParams(String)
	case nonPositiveFittsParams(String)

	public var description: String {
		switch self {
		case .unknownOperator(let tok):   return "Unknown operator: \(tok)"
		case .malformedResponse(let tok): return "Malformed response token: \(tok). Use R(0.5) style."
		case .missingFittsParams(let tok): return "Fitts' Law params missing for \(tok). Provide distance and width."
		case .nonPositiveFittsParams(let tok): return "Fitts' Law params must be > 0 for \(tok)."
		}
	}
}

// MARK: - Base trait
public protocol InterfaceUser {
	/// Per-operator times (seconds). Keys are compared UPPERCASED.
	var klmOperatorTimes: [String: Double] { get }

	/// Fitts' Law parameters (seconds; seconds/bit).
	var fittsA: Double { get } // intercept
	var fittsB: Double { get } // slope

	/// Index of Difficulty (ID) function. Default = Shannon formulation.
	func indexOfDifficulty(distance: Double, width: Double) -> Double

	/// Compute total time (seconds) for sequences like:
	/// "M P B B", "K,P,R(0.7)", "P_distance:120;width:12".
	func taskTime(for actionString: String) throws -> Double
}

// MARK: - Default implementation (desktop baseline + Shannon ID)
public extension InterfaceUser {
	var klmOperatorTimes: [String: Double] {
		[
			"K": 0.28,
			"P": 1.10,  // nominal fallback when P is unparameterized
			"H": 0.40,
			"M": 1.35,
			"B": 0.28
		]
	}

	// Typical mouse-ish defaults
	var fittsA: Double { 0.05 } // 50 ms
	var fittsB: Double { 0.10 } // 100 ms per bit

	/// Shannon formulation (most common in HCI):
	/// ID = log2(D/W + 1)
	func indexOfDifficulty(distance: Double, width: Double) -> Double {
		log2(distance / width + 1.0)
	}

	func taskTime(for actionString: String) throws -> Double {
		try breakdown(for: actionString).reduce(0) { $0 + $1.seconds }
	}

	func breakdown(for actionString: String) throws -> [(token: String, seconds: Double)] {
		let tokens = tokenize(actionString)
		var out: [(String, Double)] = []

		for raw in tokens {
			let u = raw.uppercased()

			// R(0.7) system response
			if u.hasPrefix("R(") && raw.hasSuffix(")") {
				let inner = raw.dropFirst(2).dropLast()
				guard let secs = Double(inner) else { throw KLMError.malformedResponse(raw) }
				out.append((raw, secs))
				continue
			}

			// Parameterized Fitts' Law P: "P_distance:120;width:12"
			if u.hasPrefix("P_") {
				let secs = try fittsTime(from: raw)
				out.append((raw, secs))
				continue
			}

			// Plain operators (including fallback "P")
			if let secs = klmOperatorTimes[u] {
				out.append((u, secs))
			} else {
				throw KLMError.unknownOperator(raw)
			}
		}
		return out
	}

	func fittsTime(from token: String) throws -> Double {
		let paramsPart = token.dropFirst(2) // strip "P_"
		let pairs = paramsPart.split(separator: ";").map { String($0) }

		var dict: [String: String] = [:]
		for pair in pairs {
			let kv = pair.split(separator: ":", maxSplits: 1).map {
				String($0).trimmingCharacters(in: .whitespaces)
			}
			guard kv.count == 2 else { continue }
			dict[kv[0].lowercased()] = kv[1]
		}

		let dStr = dict["distance"] ?? dict["d"]
		let wStr = dict["width"] ?? dict["w"]

		guard let dStr, let wStr, let d = Double(dStr), let w = Double(wStr) else {
			throw KLMError.missingFittsParams(String(token))
		}
		guard d > 0, w > 0 else {
			throw KLMError.nonPositiveFittsParams(String(token))
		}

		let id = indexOfDifficulty(distance: d, width: w)
		return fittsA + fittsB * id
	}

	func tokenize(_ s: String) -> [String] {
		s.split(whereSeparator: { $0 == " " || $0 == "," })
		 .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
		 .filter { !$0.isEmpty }
	}
}

// MARK: - Derived trait for wearables
public protocol WearableInterfaceUser: InterfaceUser {}

public extension WearableInterfaceUser {
	var klmOperatorTimes: [String: Double] {
		[
			"M": 1.35,
			"T": 0.25,
			"S": 0.40,
			"G": 0.50,
			"P": 0.80, // nominal wearable pointing fallback
			"B": 0.20,
			"H": 0.40
		]
	}

	// Slightly slower pointing constants (example defaults)
	var fittsA: Double { 0.10 }
	var fittsB: Double { 0.20 }
}

// MARK: - Fitts' Law variant traits  -----------------------------------------

/// 1) Shannon formulation (already the default): ID = log2(D/W + 1)
public protocol ShannonFittsUser: InterfaceUser {}
public extension ShannonFittsUser {
	func indexOfDifficulty(distance: Double, width: Double) -> Double {
		log2(distance / width + 1.0)
	}
}

/// 2) Original Fitts (1954): ID = log2(2D/W)
public protocol OriginalFittsUser: InterfaceUser {}
public extension OriginalFittsUser {
	func indexOfDifficulty(distance: Double, width: Double) -> Double {
		log2(2.0 * distance / width)
	}
}

/// 3) Welford variant: ID = log2((D + W) / W) = log2(D/W + 1)
/// (algebraically same as Shannon; included for clarity/selection)
public protocol WelfordFittsUser: InterfaceUser {}
public extension WelfordFittsUser {
	func indexOfDifficulty(distance: Double, width: Double) -> Double {
		log2((distance + width) / width)
	}
}

// MARK: - Example concrete conformers ----------------------------------------

/// Desktop + Shannon (explicit)
public struct DesktopShannonUser: InterfaceUser, ShannonFittsUser {}

/// Desktop + Original Fitts
public struct DesktopOriginalFittsUser: InterfaceUser, OriginalFittsUser {}

/// Desktop + Welford
public struct DesktopWelfordUser: InterfaceUser, WelfordFittsUser {}

public struct DesktopUser: InterfaceUser { 
	public init() {}
}

/// Wearable + Shannon (explicit)
public struct WatchShannonUser: WearableInterfaceUser, ShannonFittsUser {}

public struct WatchUser: WearableInterfaceUser { 
	public init() {}
}
/// Wearable + Original Fitts
public struct WatchOriginalFittsUser: WearableInterfaceUser, OriginalFittsUser {}