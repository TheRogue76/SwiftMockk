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

        // Generate the mock class
        let mockClass = ClassDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.public))],
            name: .identifier(mockClassName),
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier(protocolName)))
                InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("Mockable")))
            }
        ) {
            // Add internal infrastructure
            DeclSyntax("public let _mockId = UUID().uuidString")
            DeclSyntax("public var _recorder: CallRecorder { CallRecorder.shared(for: _mockId) }")
            DeclSyntax("public var _mockMode: MockMode = .strict")
            DeclSyntax("")
            DeclSyntax("public init(mode: MockMode = .strict) { _mockMode = mode }")
            DeclSyntax("")

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

    /// Generate a mock implementation for a protocol method
    private static func generateMockMethod(for funcDecl: FunctionDeclSyntax) throws -> DeclSyntax {
        let funcName = funcDecl.name.text
        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrowing = funcDecl.signature.effectSpecifiers?.throwsSpecifier != nil
        let returnType = funcDecl.signature.returnClause?.type
        let hasReturnValue = returnType != nil

        // Build parameter list for the method
        let params = funcDecl.signature.parameterClause.parameters

        // Build the argument array for recording
        let argNames = params.map { param -> String in
            let argName = param.secondName?.text ?? param.firstName.text
            return argName
        }

        let argsArrayLiteral = argNames.isEmpty ? "[]" : "[\(argNames.joined(separator: ", "))]"

        // Build the method signature
        var methodSignature = "public func \(funcName)"

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
            methodSignature += " throws"
        }
        if let returnType = returnType {
            methodSignature += " -> \(returnType.trimmedDescription)"
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
        if hasReturnValue {
            if isAsync && isThrowing {
                // Async throwing method - can propagate errors normally
                methodBody += "\n    return try await _mockGetAsyncStub(for: call, mockMode: _mockMode)"
            } else if isAsync {
                // Async non-throwing - just use try! since DSL functions handle errors
                methodBody += "\n    return try! await _mockGetAsyncStub(for: call, mockMode: _mockMode)"
            } else if isThrowing {
                // Sync throwing method - can propagate errors normally
                methodBody += "\n    return try _mockGetStub(for: call, mockMode: _mockMode)"
            } else {
                // Sync non-throwing - just use try! since DSL functions handle errors
                methodBody += "\n    return try! _mockGetStub(for: call, mockMode: _mockMode)"
            }
        } else {
            // Void method
            if isThrowing {
                methodBody += "\n    try _mockExecuteThrowingStub(for: call)"
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
