import Foundation

/// Represents information about a protocol that needs mock generation
public struct ProtocolInfo: Sendable {
    /// The name of the protocol
    public let name: String

    /// Generic parameters for the protocol (e.g., "<Entity>" from "protocol Repository<Entity>")
    public let genericParameters: String?

    /// Where clause constraints (e.g., "where Key: Hashable")
    public let whereClause: String?

    /// Associated type declarations converted to generic parameters
    public let associatedTypes: [AssociatedTypeInfo]

    /// Methods declared in the protocol
    public let methods: [MethodInfo]

    /// Properties declared in the protocol
    public let properties: [PropertyInfo]

    /// The module name where the protocol is defined (for import statements)
    public let moduleName: String?

    public init(
        name: String,
        genericParameters: String? = nil,
        whereClause: String? = nil,
        associatedTypes: [AssociatedTypeInfo] = [],
        methods: [MethodInfo] = [],
        properties: [PropertyInfo] = [],
        moduleName: String? = nil
    ) {
        self.name = name
        self.genericParameters = genericParameters
        self.whereClause = whereClause
        self.associatedTypes = associatedTypes
        self.methods = methods
        self.properties = properties
        self.moduleName = moduleName
    }
}

/// Represents an associated type in a protocol
public struct AssociatedTypeInfo: Sendable {
    /// The name of the associated type
    public let name: String

    /// Constraints on the associated type (e.g., "where T: Codable")
    public let constraints: String?

    public init(name: String, constraints: String? = nil) {
        self.name = name
        self.constraints = constraints
    }
}

/// Represents a method in a protocol
public struct MethodInfo: Sendable {
    /// The method name
    public let name: String

    /// Generic parameters for the method (e.g., "<T: Decodable>")
    public let genericParameters: String?

    /// Generic where clause for the method
    public let genericWhereClause: String?

    /// The method parameters
    public let parameters: [ParameterInfo]

    /// Whether the method is async
    public let isAsync: Bool

    /// Whether the method throws
    public let isThrowing: Bool

    /// The typed throws clause (e.g., "(UserError)" from "throws(UserError)")
    /// Empty string for untyped throws, nil for non-throwing
    public let throwsClause: String?

    /// The return type (nil for void methods)
    public let returnType: String?

    public init(
        name: String,
        genericParameters: String? = nil,
        genericWhereClause: String? = nil,
        parameters: [ParameterInfo] = [],
        isAsync: Bool = false,
        isThrowing: Bool = false,
        throwsClause: String? = nil,
        returnType: String? = nil
    ) {
        self.name = name
        self.genericParameters = genericParameters
        self.genericWhereClause = genericWhereClause
        self.parameters = parameters
        self.isAsync = isAsync
        self.isThrowing = isThrowing
        self.throwsClause = throwsClause
        self.returnType = returnType
    }

    /// Whether this method has typed throws
    public var hasTypedThrows: Bool {
        guard let clause = throwsClause else { return false }
        return !clause.isEmpty
    }

    /// The error type name for typed throws (without parentheses)
    public var typedThrowsErrorType: String? {
        guard let clause = throwsClause, !clause.isEmpty else { return nil }
        // Remove parentheses: "(UserError)" -> "UserError"
        return String(clause.dropFirst().dropLast())
    }
}

/// Represents a parameter in a method
public struct ParameterInfo: Sendable {
    /// External parameter name (used at call site)
    public let externalName: String?

    /// Internal parameter name (used in implementation)
    public let internalName: String

    /// The type of the parameter
    public let type: String

    /// Default value if any
    public let defaultValue: String?

    /// Whether this is a variadic parameter pack (contains "repeat each")
    public let isVariadicPack: Bool

    public init(
        externalName: String?,
        internalName: String,
        type: String,
        defaultValue: String? = nil,
        isVariadicPack: Bool = false
    ) {
        self.externalName = externalName
        self.internalName = internalName
        self.type = type
        self.defaultValue = defaultValue
        self.isVariadicPack = isVariadicPack
    }
}

/// Represents a property in a protocol
public struct PropertyInfo: Sendable {
    /// The property name
    public let name: String

    /// The type of the property
    public let type: String

    /// Whether the property has a setter
    public let isGetSet: Bool

    public init(name: String, type: String, isGetSet: Bool) {
        self.name = name
        self.type = type
        self.isGetSet = isGetSet
    }
}
