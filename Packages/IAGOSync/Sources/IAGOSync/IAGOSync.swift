import Foundation
import IAGOCore

/// IAGOSync — E2E sync interfaces only until phase 4 (see ADR-0012).
public enum IAGOSyncModule {
    public static let name = "IAGOSync"
}

/// Pushes local changes (from `change_log`) and pulls remote ones. Implemented in phase 4.
public protocol SyncClient: Sendable {
    func push() async throws
    func pull() async throws
}

/// Wraps and unwraps project keys for project members. Implemented in phase 4.
public protocol ProjectKeyring: Sendable {
    func wrapProjectKey(_ key: Data, forMemberPublicKey publicKey: Data) throws -> Data
    func unwrapProjectKey(_ wrapped: Data) throws -> Data
}
