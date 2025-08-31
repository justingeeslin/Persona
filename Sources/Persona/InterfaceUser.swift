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

/// Unified operator spec that includes time and human-friendly metadata
public struct OperatorInfo: Equatable {
    public let code: String            // canonical token, e.g., "K", "P", "R"
    public let time: Double            // baseline time in seconds
    public let name: String            // short label (e.g., "Keystroke")
    public let longDescription: String // longer description

    public init(code: String, time: Double, name: String, longDescription: String) {
        self.code = code.uppercased()
        self.time = time
        self.name = name
        self.longDescription = longDescription
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
    
    /// Override or extend full operator specifications (time + metadata).
    var operatorInfoOverrides: [OperatorInfo] { get }

    /// Index of Difficulty (ID) function. Default = Shannon formulation.
    func indexOfDifficulty(distance: Double, width: Double) -> Double

    /// Compute total time (seconds) for sequences like:
    /// "M P B B", "K,P,R(0.7)", "P_distance:120;width:12".
    func taskTime(for actionString: String) throws -> Double
}

// MARK: - Default implementation (desktop baseline + Shannon ID)
public extension InterfaceUser {
    // Basic KLM operators as unified specs (time + metadata)
    var baseOperatorInfos: [OperatorInfo] {
        [
            OperatorInfo(code: "M", time: 1.20, name: "Mental Preparation", longDescription: "Cognitive preparation or decision step before execution."),
            OperatorInfo(code: "H", time: 0.40, name: "Homing", longDescription: "Move hands between devices or device and eyes."),
            // Response token baseline when explicit seconds are not provided
            OperatorInfo(code: "R", time: 0.0, name: "System Response", longDescription: "Waiting time for the system to respond; specify as R(seconds) to override."),
            
        ]
    }

    /// Derive the legacy base time table from specs for internal use/merging
    var baseKLMOperatorTimes: [String: Double] {
        var dict: [String: Double] = [:]
        for info in baseOperatorInfos { dict[info.code] = info.time }
        return dict
    }
    
    // Mouse a and b; Card et al, 1978; Is this appropriate? Yes, for now.
    var fittsA: Double { 1.03 }
    var fittsB: Double { 0.096 }

    /// Override or extend operator timings. Keys are compared UPPERCASED.
    var klmOperatorOverrides: [String: Double] { [:] }

    /// Final operator table = base + overrides (overrides replace on key match, add otherwise)
    var klmOperatorTimes: [String: Double] {
        // Start from merged operator infos (base + operatorInfoOverrides)
        var merged: [String: Double] = [:]
        for info in allOperatorInfos { merged[info.code] = info.time }
        // Then apply any time-only overrides last for final say
        for (k, v) in klmOperatorOverrides {
            merged[k.uppercased()] = v
        }
        return merged
    }

    /// Default: no operator info overrides
    var operatorInfoOverrides: [OperatorInfo] { [] }

    /// Final merged operator infos = base + overrides
    var allOperatorInfos: [OperatorInfo] {
        var dict: [String: OperatorInfo] = [:]
        for info in baseOperatorInfos { dict[info.code] = info }
        for info in operatorInfoOverrides { dict[info.code] = info }
        return Array(dict.values)
    }

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
    
    /// Lookup metadata for a raw token (normalizes parameterized tokens like P_distance:..;width:.. and R(seconds))
    func operatorInfo(for token: String) -> OperatorInfo? {
        let u = token.uppercased()
        if u.hasPrefix("P_") { return allOperatorInfos.first { $0.code == "P" } }
        if u.hasPrefix("R(") && u.hasSuffix(")") { return allOperatorInfos.first { $0.code == "R" } }
        return allOperatorInfos.first { $0.code == u }
    }
}

public protocol MouseKeyboardInterfaceUser : InterfaceUser {}
public extension MouseKeyboardInterfaceUser {
    var operatorInfoOverrides: [OperatorInfo] {
        [
            // Common desktop ops
            OperatorInfo(code: "K", time: 0.28, name: "Keystroke", longDescription: "Press a key on the keyboard or equivalent discrete input."),
            OperatorInfo(code: "P", time: 1.10, name: "Point", longDescription: "Move pointing device to a target (Fitts-based when parameterized)."),
            OperatorInfo(code: "B", time: 0.10, name: "Button Press", longDescription: "Press a physical/on-device button distinct from a key or tap."),
            
        ]
    }
}

// Same operators as MouseKeyboard, but with different a and b
public protocol JoystickInterfaceUser : MouseKeyboardInterfaceUser {}
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
    
    var operatorInfoOverrides: [OperatorInfo] {
        [
            OperatorInfo(code: "T", time: 0.28, name: "Tap", longDescription: "Single tap on watch screen."),
            OperatorInfo(code: "TT", time: 0.43, name: "Double Tap", longDescription: "Two quick taps on watch screen."),
            OperatorInfo(code: "TH", time: 0.78, name: "Tap and Hold", longDescription: "Tap and hold on watch screen."),
            OperatorInfo(code: "I", time: 0.82, name: "Initial Raise", longDescription: "Raise wrist to field of view."),
            OperatorInfo(code: "H", time: 0.57, name: "Homing", longDescription: "Move hand to interact with watch."),
            OperatorInfo(code: "S", time: 0.75, name: "Silencing Gesture", longDescription: "Gesture to silence/dismiss alerts on watch.")
        ]
    }
}

public protocol MobileInterfaceUser: InterfaceUser {
    
}

public extension MobileInterfaceUser {
    
    var operatorInfoOverrides: [OperatorInfo] {
        [
            // Common desktop ops
            OperatorInfo(code: "T", time: 0.31, name: "Tap", longDescription: "Press a key on the keyboard or equivalent discrete input."),
            OperatorInfo(code: "P", time: 0.43, name: "Point", longDescription: "Move pointing device to a target (Fitts-based when parameterized)."),
            OperatorInfo(code: "D", time: 0.17, name: "Drag", longDescription: "Drag"),
            OperatorInfo(code: "F", time: 0.11, name: "Flick", longDescription: "Flick (left to right) (right to left is 0.12)"),
            
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
public struct DesktopShannonUser: MouseKeyboardInterfaceUser, ShannonFittsUser {}

/// Desktop + Original Fitts
public struct DesktopOriginalFittsUser: MouseKeyboardInterfaceUser, OriginalFittsUser {}

/// Desktop + Welford
public struct DesktopWelfordUser: MouseKeyboardInterfaceUser, WelfordFittsUser {}

public struct DesktopUser: MouseKeyboardInterfaceUser {
    public init() {}
}

public struct WatchUser: WatchInterfaceUser {
    public init() {}
}

public struct MobileUser: MobileInterfaceUser {
    public init() {}
}
