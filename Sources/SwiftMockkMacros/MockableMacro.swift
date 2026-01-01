import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Peer macro that generates a mock implementation of a protocol
public struct MockableMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Ensure the macro is applied to a protocol
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            throw MockableError.notAProtocol
        }

        let protocolName = protocolDecl.name.text
        let mockClassName = "Mock\(protocolName)"

        // Extract protocol-level generic parameters and constraints
        let protocolGenerics = extractProtocolGenericParameters(from: protocolDecl)
        let protocolWhereClause = extractProtocolWhereClause(from: protocolDecl)

        // Extract associated types and convert to generic parameters
        let associatedTypes = extractAssociatedTypes(from: protocolDecl)

        // Determine final generic parameters (merge protocol generics with associated types)
        let finalGenerics: String?
        let finalWhereClause: String?

        if !associatedTypes.isEmpty && protocolGenerics == nil {
            // Convert associated types to generic parameters
            let typeNames = associatedTypes.map { $0.name }
            finalGenerics = "<\(typeNames.joined(separator: ", "))>"

            // Merge where clauses from associated types
            let assocWhereConstraints = associatedTypes.compactMap { $0.constraints }
            if !assocWhereConstraints.isEmpty {
                // Extract constraints without "where " prefix
                let constraints = assocWhereConstraints.map { constraint in
                    constraint.hasPrefix("where ") ? String(constraint.dropFirst(6)) : constraint
                }
                finalWhereClause = "where \(constraints.joined(separator: ", "))"
            } else {
                finalWhereClause = protocolWhereClause
            }
        } else {
            finalGenerics = protocolGenerics
            finalWhereClause = protocolWhereClause
        }

        // Extract methods and properties from the protocol
        var mockMethods: [DeclSyntax] = []
        var mockProperties: [DeclSyntax] = []

        for member in protocolDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                let mockMethod = try generateMockMethod(for: funcDecl)
                mockMethods.append(mockMethod)
            } else if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                let properties = try generateMockProperties(for: varDecl)
                mockProperties.append(contentsOf: properties)
            }
        }

        // Build class declaration with generics
        var classDeclaration = "public class \(mockClassName)"
        if let generics = finalGenerics {
            classDeclaration += generics
        }
        classDeclaration += ": \(protocolName), Mockable"
        if let whereClause = finalWhereClause {
            classDeclaration += " \(whereClause)"
        }

        // Generate the mock class using string literal approach for complex generic syntax
        let mockClass = try ClassDeclSyntax("\(raw: classDeclaration)") {
            // Add internal infrastructure
            DeclSyntax("public let _mockId = UUID().uuidString")
            DeclSyntax("public var _recorder: CallRecorder { CallRecorder.shared(for: _mockId) }")
            DeclSyntax("public var _mockMode: MockMode = .strict")
            DeclSyntax("")
            DeclSyntax("public init(mode: MockMode = .strict) { _mockMode = mode }")
            DeclSyntax("")

            // Add typealias declarations for associated types
            for (name, _) in associatedTypes {
                DeclSyntax("public typealias \(raw: name) = \(raw: name)")
            }

            // Add all mock properties
            for property in mockProperties {
                property
            }

            // Add all mock methods
            for method in mockMethods {
                method
            }
        }

        return [DeclSyntax(mockClass)]
    }

    /// Extract throws clause information from function declaration
    /// swift-syntax 600.0.0+ has proper typed throws support
    /// Returns whether the method throws (used for detection only, not code generation)
    private static func extractThrowsInfo(
        from funcDecl: FunctionDeclSyntax
    ) -> (isThrowing: Bool, clause: String) {
        guard let effectSpecifiers = funcDecl.signature.effectSpecifiers,
              let throwsClause = effectSpecifiers.throwsClause else {
            return (false, "")
        }

        // Check if there's a type in the throws clause
        if let throwType = throwsClause.type {
            let typeString = throwType.trimmedDescription
            return (true, "(\(typeString))")
        }

        // Untyped throws
        return (true, "")
    }

    /// Extract generic parameter clause from a function declaration
    private static func extractGenericParameters(
        from funcDecl: FunctionDeclSyntax
    ) -> String? {
        guard let genericParams = funcDecl.genericParameterClause else {
            return nil
        }
        return genericParams.trimmedDescription
    }

    /// Extract generic where clause from a function declaration
    private static func extractGenericWhereClause(
        from funcDecl: FunctionDeclSyntax
    ) -> String? {
        guard let whereClause = funcDecl.genericWhereClause else {
            return nil
        }
        return whereClause.trimmedDescription
    }

    /// Extract generic parameter clause from a protocol declaration
    /// Converts primary associated types to generic parameters
    private static func extractProtocolGenericParameters(
        from protocolDecl: ProtocolDeclSyntax
    ) -> String? {
        // Primary associated types (Swift 5.7+)
        if let primaryAssociatedTypes = protocolDecl.primaryAssociatedTypeClause {
            let typeNames = primaryAssociatedTypes.primaryAssociatedTypes.map { $0.name.text }
            return "<\(typeNames.joined(separator: ", "))>"
        }

        return nil
    }

    /// Extract where clause from protocol declaration
    private static func extractProtocolWhereClause(
        from protocolDecl: ProtocolDeclSyntax
    ) -> String? {
        guard let whereClause = protocolDecl.genericWhereClause else {
            return nil
        }
        return whereClause.trimmedDescription
    }

    /// Extract associated type declarations from protocol
    /// Returns list of (name, constraints) tuples
    private static func extractAssociatedTypes(
        from protocolDecl: ProtocolDeclSyntax
    ) -> [(name: String, constraints: String?)] {
        var associatedTypes: [(String, String?)] = []

        for member in protocolDecl.memberBlock.members {
            if let assocType = member.decl.as(AssociatedTypeDeclSyntax.self) {
                let name = assocType.name.text
                let constraints = assocType.genericWhereClause?.trimmedDescription
                associatedTypes.append((name, constraints))
            }
        }

        return associatedTypes
    }

    /// Generate a mock implementation for a protocol method
    private static func generateMockMethod(for funcDecl: FunctionDeclSyntax) throws -> DeclSyntax {
        let funcName = funcDecl.name.text
        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let throwsInfo = extractThrowsInfo(from: funcDecl)
        let isThrowing = throwsInfo.isThrowing
        let returnType = funcDecl.signature.returnClause?.type
        let hasReturnValue = returnType != nil

        // Build parameter list for the method
        let params = funcDecl.signature.parameterClause.parameters

        // Build the argument array for recording
        let argElements = params.compactMap { param -> String? in
            let argName = param.secondName?.text ?? param.firstName.text
            let typeDesc = param.type.trimmedDescription

            // Check if this is a variadic parameter pack (contains "repeat each")
            if typeDesc.contains("repeat each") {
                // Parameter packs can't be easily type-erased to [Any]
                // Skip them in argument recording - verification will work by method name
                return nil
            } else {
                return argName
            }
        }

        let argsArrayLiteral = argElements.isEmpty ? "[]" : "[\(argElements.joined(separator: ", "))]"

        // Build the method signature
        var methodSignature = "public func \(funcName)"

        // Add generic parameters if present
        if let genericParams = extractGenericParameters(from: funcDecl) {
            methodSignature += genericParams
        }

        let paramStrings = params.map { param -> String in
            let firstName = param.firstName.text
            let secondName = param.secondName?.text
            let paramName = secondName != nil ? "\(firstName) \(secondName!)" : firstName
            let type = param.type.trimmedDescription
            let defaultValue = param.defaultValue != nil ? " \(param.defaultValue!.trimmedDescription)" : ""
            return "\(paramName): \(type)\(defaultValue)"
        }

        methodSignature += "(\(paramStrings.joined(separator: ", ")))"

        if isAsync {
            methodSignature += " async"
        }
        if isThrowing {
            // Preserve typed throws from protocol
            methodSignature += " throws\(throwsInfo.clause)"
        }
        if let returnType = returnType {
            methodSignature += " -> \(returnType.trimmedDescription)"
        }

        // Add where clause if present (MUST come after return type)
        if let whereClause = extractGenericWhereClause(from: funcDecl) {
            methodSignature += " \(whereClause)"
        }

        // Build the method body - use wrapper functions that handle mode checking
        var methodBody = """
        {
            let matchers = MatcherRegistry.shared.extractMatchers()
            let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
            let call = MethodCall(mockId: _mockId, name: "\(funcName)", args: \(argsArrayLiteral), matchMode: matchMode)
            _recorder.record(call)
        """

        // Add stub lookup using helper functions
        // For typed throws, use special helpers that fatal error instead of throwing MockError
        let hasTypedThrows = !throwsInfo.clause.isEmpty
        let errorTypeName = hasTypedThrows ? String(throwsInfo.clause.dropFirst().dropLast()) : ""

        if hasReturnValue {
            if isAsync && isThrowing {
                // Async throwing method
                if hasTypedThrows {
                    methodBody += """

                        return try await _mockGetTypedAsyncStub(
                            for: call, mockMode: _mockMode, errorType: \(errorTypeName).self)
                    """
                } else {
                    methodBody += "\n    return try await _mockGetAsyncStub(for: call, mockMode: _mockMode)"
                }
            } else if isAsync {
                // Async non-throwing - just use try! since DSL functions handle errors
                methodBody += "\n    return try! await _mockGetAsyncStub(for: call, mockMode: _mockMode)"
            } else if isThrowing {
                // Sync throwing method
                if hasTypedThrows {
                    methodBody += """

                        return try _mockGetTypedStub(
                            for: call, mockMode: _mockMode, errorType: \(errorTypeName).self)
                    """
                } else {
                    methodBody += "\n    return try _mockGetStub(for: call, mockMode: _mockMode)"
                }
            } else {
                // Sync non-throwing - just use try! since DSL functions handle errors
                methodBody += "\n    return try! _mockGetStub(for: call, mockMode: _mockMode)"
            }
        } else {
            // Void method
            if isThrowing {
                if hasTypedThrows {
                    methodBody += "\n    try _mockExecuteTypedThrowingStub(for: call, errorType: \(errorTypeName).self)"
                } else {
                    methodBody += "\n    try _mockExecuteThrowingStub(for: call)"
                }
            }
        }

        methodBody += "\n}"

        let fullMethod = methodSignature + " " + methodBody

        return DeclSyntax(stringLiteral: fullMethod)
    }

    /// Generate mock properties for a protocol variable declaration
    private static func generateMockProperties(for varDecl: VariableDeclSyntax) throws -> [DeclSyntax] {
        var properties: [DeclSyntax] = []

        // Check if it's a property (not a static var, etc.)
        guard !varDecl.modifiers.contains(where: { $0.name.text == "static" }) else {
            return []
        }

        for binding in varDecl.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation else {
                continue
            }

            let propertyName = pattern.identifier.text
            let propertyType = typeAnnotation.type.trimmedDescription

            // Check if it's get-only or get-set
            let isGetSet: Bool
            if let accessor = binding.accessorBlock {
                // Check for { get set } or { get }
                if let accessorList = accessor.accessors.as(AccessorDeclListSyntax.self) {
                    let hasSet = accessorList.contains { $0.accessorSpecifier.text == "set" }
                    isGetSet = hasSet
                } else {
                    // Assume get-set if not specified
                    isGetSet = true
                }
            } else {
                // If no accessor block, default to get-set
                isGetSet = true
            }

            // Generate backing storage
            let backingVar = DeclSyntax(stringLiteral: "private var _\(propertyName): \(propertyType)?")
            properties.append(backingVar)

            // Generate the property with getter and optionally setter
            if isGetSet {
                // swiftlint:disable:next line_length
                let property = DeclSyntax(stringLiteral: """
                public var \(propertyName): \(propertyType) {
                    get {
                        let matchers = MatcherRegistry.shared.extractMatchers()
                        let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                        let call = MethodCall(mockId: _mockId, name: "get_\(propertyName)", args: [], matchMode: matchMode)
                        _recorder.record(call)
                        if let value = _\(propertyName) {
                            return value
                        }
                        return try! _mockGetStub(for: call, mockMode: _mockMode)
                    }
                    set {
                        let matchers = MatcherRegistry.shared.extractMatchers()
                        let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                        let call = MethodCall(mockId: _mockId, name: "set_\(propertyName)", args: [newValue], matchMode: matchMode)
                        _recorder.record(call)
                        _\(propertyName) = newValue
                    }
                }
                """)
                properties.append(property)
            } else {
                // Get-only property
                // swiftlint:disable:next line_length
                let property = DeclSyntax(stringLiteral: """
                public var \(propertyName): \(propertyType) {
                    get {
                        let matchers = MatcherRegistry.shared.extractMatchers()
                        let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                        let call = MethodCall(mockId: _mockId, name: "get_\(propertyName)", args: [], matchMode: matchMode)
                        _recorder.record(call)
                        if let value = _\(propertyName) {
                            return value
                        }
                        return try! _mockGetStub(for: call, mockMode: _mockMode)
                    }
                }
                """)
                properties.append(property)
            }
        }

        return properties
    }
}

enum MockableError: Error, CustomStringConvertible {
    case notAProtocol

    var description: String {
        switch self {
        case .notAProtocol:
            return "@Mockable can only be applied to protocols"
        }
    }
}
