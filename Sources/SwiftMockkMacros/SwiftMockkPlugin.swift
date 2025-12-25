import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftMockkPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        MockableMacro.self,
    ]
}
