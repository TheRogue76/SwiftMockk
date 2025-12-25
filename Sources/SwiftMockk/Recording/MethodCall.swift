/// Represents a single method call on a mock
public struct MethodCall: Equatable, @unchecked Sendable {
    /// Unique identifier for the mock instance
    public let mockId: String

    /// The name of the method
    public let name: String

    /// The arguments passed to the method
    public let args: [Any]

    /// How arguments should be matched
    public let matchMode: MatchMode

    public init(mockId: String, name: String, args: [Any], matchMode: MatchMode = .exact) {
        self.mockId = mockId
        self.name = name
        self.args = args
        self.matchMode = matchMode
    }

    /// Determines how arguments are matched during verification
    public enum MatchMode: Sendable {
        case exact
        case matchers([any ArgumentMatcher])
    }

    /// Check if this call matches another call based on the match mode
    public func matches(_ other: MethodCall) -> Bool {
        guard name == other.name else { return false }
        guard args.count == other.args.count else { return false }

        switch matchMode {
        case .exact:
            return zip(args, other.args).allSatisfy { areEqual($0, $1) }
        case .matchers(let matchers):
            return zip(matchers, other.args).allSatisfy { $0.matches($1) }
        }
    }

    public static func == (lhs: MethodCall, rhs: MethodCall) -> Bool {
        guard lhs.mockId == rhs.mockId else { return false }
        guard lhs.name == rhs.name else { return false }
        guard lhs.args.count == rhs.args.count else { return false }
        return zip(lhs.args, rhs.args).allSatisfy { areEqual($0, $1) }
    }
}

/// Helper function to compare Any values for equality
func areEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    // Try to cast to common Equatable types
    if let lhs = lhs as? any Equatable, let rhs = rhs as? any Equatable {
        return isEqual(lhs, to: rhs)
    }
    return false
}

/// Type-erased equality check
private func isEqual(_ lhs: any Equatable, to rhs: any Equatable) -> Bool {
    // Check if types match
    guard type(of: lhs) == type(of: rhs) else { return false }

    // Try to cast and compare
    // This is a bit hacky but necessary for type-erased comparison
    return "\(lhs)" == "\(rhs)"
}

/// Protocol for argument matchers
public protocol ArgumentMatcher: Sendable {
    func matches(_ value: Any) -> Bool
}
