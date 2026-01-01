import SwiftSyntax
import SwiftParser

/// Parses SwiftSyntax protocol declarations into ProtocolInfo
public struct ProtocolParser {

    public init() {}

    /// Parse a ProtocolDeclSyntax into ProtocolInfo
    public func parse(_ protocolDecl: ProtocolDeclSyntax, moduleName: String? = nil, imports: [String] = []) -> ProtocolInfo {
        let name = protocolDecl.name.text

        // Extract protocol-level generic parameters
        let genericParameters = extractProtocolGenericParameters(from: protocolDecl)
        let whereClause = extractProtocolWhereClause(from: protocolDecl)

        // Extract associated types
        let associatedTypes = extractAssociatedTypes(from: protocolDecl)

        // Extract methods and properties
        var methods: [MethodInfo] = []
        var properties: [PropertyInfo] = []

        for member in protocolDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                methods.append(parseMethod(funcDecl))
            } else if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                properties.append(contentsOf: parseProperties(varDecl))
            }
        }

        return ProtocolInfo(
            name: name,
            genericParameters: genericParameters,
            whereClause: whereClause,
            associatedTypes: associatedTypes,
            methods: methods,
            properties: properties,
            moduleName: moduleName,
            imports: imports
        )
    }

    /// Parse Swift source code and extract all protocols
    public func parseSource(_ source: String, moduleName: String? = nil) -> [ProtocolInfo] {
        let sourceFile = Parser.parse(source: source)
        var protocols: [ProtocolInfo] = []

        for statement in sourceFile.statements {
            if let protocolDecl = statement.item.as(ProtocolDeclSyntax.self) {
                protocols.append(parse(protocolDecl, moduleName: moduleName))
            }
        }

        return protocols
    }

    // MARK: - Private Helpers

    private func extractProtocolGenericParameters(from protocolDecl: ProtocolDeclSyntax) -> String? {
        // Primary associated types (Swift 5.7+)
        if let primaryAssociatedTypes = protocolDecl.primaryAssociatedTypeClause {
            let typeNames = primaryAssociatedTypes.primaryAssociatedTypes.map { $0.name.text }
            return "<\(typeNames.joined(separator: ", "))>"
        }
        return nil
    }

    private func extractProtocolWhereClause(from protocolDecl: ProtocolDeclSyntax) -> String? {
        guard let whereClause = protocolDecl.genericWhereClause else {
            return nil
        }
        return whereClause.trimmedDescription
    }

    private func extractAssociatedTypes(from protocolDecl: ProtocolDeclSyntax) -> [AssociatedTypeInfo] {
        var associatedTypes: [AssociatedTypeInfo] = []

        for member in protocolDecl.memberBlock.members {
            if let assocType = member.decl.as(AssociatedTypeDeclSyntax.self) {
                let name = assocType.name.text
                let constraints = assocType.genericWhereClause?.trimmedDescription
                associatedTypes.append(AssociatedTypeInfo(name: name, constraints: constraints))
            }
        }

        return associatedTypes
    }

    private func parseMethod(_ funcDecl: FunctionDeclSyntax) -> MethodInfo {
        let name = funcDecl.name.text
        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil

        // Extract throws info
        let (isThrowing, throwsClause) = extractThrowsInfo(from: funcDecl)

        // Extract return type
        let returnType = funcDecl.signature.returnClause?.type.trimmedDescription

        // Extract generic parameters
        let genericParameters = funcDecl.genericParameterClause?.trimmedDescription
        let genericWhereClause = funcDecl.genericWhereClause?.trimmedDescription

        // Extract parameters
        let parameters = funcDecl.signature.parameterClause.parameters.map { param -> ParameterInfo in
            let firstName = param.firstName.text
            let secondName = param.secondName?.text
            let type = param.type.trimmedDescription
            let defaultValue = param.defaultValue?.value.trimmedDescription
            let isVariadicPack = type.contains("repeat each")

            // Determine external and internal names
            let externalName: String?
            let internalName: String

            if firstName == "_" {
                externalName = nil
                internalName = secondName ?? firstName
            } else if let second = secondName {
                externalName = firstName
                internalName = second
            } else {
                externalName = firstName
                internalName = firstName
            }

            return ParameterInfo(
                externalName: externalName,
                internalName: internalName,
                type: type,
                defaultValue: defaultValue,
                isVariadicPack: isVariadicPack
            )
        }

        return MethodInfo(
            name: name,
            genericParameters: genericParameters,
            genericWhereClause: genericWhereClause,
            parameters: parameters,
            isAsync: isAsync,
            isThrowing: isThrowing,
            throwsClause: throwsClause,
            returnType: returnType
        )
    }

    private func extractThrowsInfo(from funcDecl: FunctionDeclSyntax) -> (isThrowing: Bool, clause: String?) {
        guard let effectSpecifiers = funcDecl.signature.effectSpecifiers,
              let throwsClause = effectSpecifiers.throwsClause else {
            return (false, nil)
        }

        // Check if there's a type in the throws clause
        if let throwType = throwsClause.type {
            let typeString = throwType.trimmedDescription
            return (true, "(\(typeString))")
        }

        // Untyped throws
        return (true, "")
    }

    private func parseProperties(_ varDecl: VariableDeclSyntax) -> [PropertyInfo] {
        var properties: [PropertyInfo] = []

        // Skip static properties
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
                if let accessorList = accessor.accessors.as(AccessorDeclListSyntax.self) {
                    let hasSet = accessorList.contains { $0.accessorSpecifier.text == "set" }
                    isGetSet = hasSet
                } else {
                    isGetSet = true
                }
            } else {
                isGetSet = true
            }

            properties.append(PropertyInfo(
                name: propertyName,
                type: propertyType,
                isGetSet: isGetSet
            ))
        }

        return properties
    }
}
