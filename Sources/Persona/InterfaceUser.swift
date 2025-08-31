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

    /// Override or extend operator timings. Keys are compared UPPERCASED.
    var klmOperatorOverrides: [String: Double] { get }
    
    /// Index of Difficulty (ID) function. Default = Shannon formulation.
    func indexOfDifficulty(distance: Double, width: Double) -> Double

    /// Compute total time (seconds) for sequences like:
    /// "M P B B", "K,P,R(0.7)", "P_distance:120;width:12".
    func taskTime(for actionString: String) throws -> Double
}

// MARK: - Default implementation (desktop baseline + Shannon ID)
public extension InterfaceUser {
    // Basic KLM operators; Kieras 1993
    var baseKLMOperatorTimes: [String: Double] {
        [
            "K": 0.28,
            "P": 1.10,
            "H": 0.40,
            "M": 1.2,
            "B": 0.1
        ]
    }

    /// Override or extend operator timings. Keys are compared UPPERCASED.
    var klmOperatorOverrides: [String: Double] { [:] }

    /// Final operator table = base + overrides (overrides replace on key match, add otherwise)
    var klmOperatorTimes: [String: Double] {
        var merged = baseKLMOperatorTimes
        for (k, v) in klmOperatorOverrides {
            merged[k.uppercased()] = v
        }
        return merged
    }

    // Mouse a and b; Card et al, 1978
    var fittsA: Double { 1.03 }
    var fittsB: Double { 0.096 }

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

public protocol MouseInterfaceUser : InterfaceUser {}

public protocol JoystickInterfaceUser : InterfaceUser {}
public extension JoystickInterfaceUser {
    // Joystick a and b; Card et al, 1978
    var fittsA: Double { 0.99 }
    var fittsB: Double { 0.220 }
}

// MARK: - Derived trait for wearables
public protocol WearableInterfaceUser: InterfaceUser {}

public extension WearableInterfaceUser {
    // TODO :)
}

public protocol WatchInterfaceUser: WearableInterfaceUser {
    
}

public extension WatchInterfaceUser {
    
    var klmOperatorOverrides: [String: Double] {
        [
            // Wearable-specific additions; Al-Megren, 2018
            // Tap
            "T": 0.28,
            // Double Tap
            "TT": 0.43,
            // Tap and Hold
            "TH": 0.78,
            // Press - refers to on-device buttons
            
            // Initial action - raising the non-dominant wrist to field of view
            "I": 0.82,
            "H": 0.57,
            // Silencing gesture -
            "S": 0.75
        ]
    }
}

public protocol MobileInterfaceUser: InterfaceUser {
    
}

public extension MobileInterfaceUser {
    
    var klmOperatorOverrides: [String: Double] {
        [
            // Mobile-specific additions; Lee et al. 2015
            "T": 0.31,
            "P": 0.43,
            "D": 0.17,
            "F": 0.11,
        ]
    }
    // Mobile a and b; Lee et al. 2015
    var fittsA: Double { 0.1035 }
    var fittsB: Double { 0.1257 }
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

public struct DesktopUser: MouseInterfaceUser {
    public init() {}
}

/// Wearable + Shannon (explicit)
public struct WatchShannonUser: WearableInterfaceUser, ShannonFittsUser {}

public struct WatchUser: WatchInterfaceUser {
    public init() {}
}

public struct MobileUser: MobileInterfaceUser {
    public init() {}
}
/// Wearable + Original Fitts
public struct WatchOriginalFittsUser: WearableInterfaceUser, OriginalFittsUser {}
