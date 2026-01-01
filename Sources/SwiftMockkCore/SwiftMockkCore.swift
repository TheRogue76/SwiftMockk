// SwiftMockkCore - Shared code generation logic for SwiftMockk
//
// This module provides the core mock generation functionality used by both:
// - The @Mockable macro (SwiftMockkMacros)
// - The SwiftMockkGenerator CLI (for build-phase generation)

@_exported import struct Foundation.UUID
@_exported import struct Foundation.Date
@_exported import class Foundation.ISO8601DateFormatter

// Re-export all public types
public typealias _ProtocolInfo = ProtocolInfo
public typealias _MethodInfo = MethodInfo
public typealias _PropertyInfo = PropertyInfo
public typealias _ParameterInfo = ParameterInfo
public typealias _AssociatedTypeInfo = AssociatedTypeInfo
public typealias _MockGenerator = MockGenerator
public typealias _ProtocolParser = ProtocolParser
