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

        // Extract methods from the protocol
        var mockMethods: [DeclSyntax] = []

        for member in protocolDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                let mockMethod = try generateMockMethod(for: funcDecl)
                mockMethods.append(mockMethod)
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
            DeclSyntax("")
            DeclSyntax("public init() {}")
            DeclSyntax("")

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

        // Build the method body
        var methodBody = """
        {
            let matchers = MatcherRegistry.shared.extractMatchers()
            let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
            let call = MethodCall(mockId: _mockId, name: "\(funcName)", args: \(argsArrayLiteral), matchMode: matchMode)
            await _recorder.record(call)
        """

        if hasReturnValue {
            if isAsync {
                methodBody += "\n    return try await StubbingRegistry.shared.getAsyncStub(for: call)"
            } else if isThrowing {
                methodBody += "\n    return try StubbingRegistry.shared.getStub(for: call)"
            } else {
                methodBody += "\n    return try! StubbingRegistry.shared.getStub(for: call)"
            }
        } else {
            if isThrowing {
                methodBody += "\n    try StubbingRegistry.shared.executeThrowingStub(for: call)"
            }
        }

        methodBody += "\n}"

        let fullMethod = methodSignature + " " + methodBody

        return DeclSyntax(stringLiteral: fullMethod)
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
