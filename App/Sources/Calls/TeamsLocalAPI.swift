import Foundation
import IAGOCore
import IAGOStore
import Observation
import Security
import os

/// Teams' local third-party app API (ADR-0051): a WebSocket on 127.0.0.1:8124, enabled by the user in Teams ›
/// Settings › Privacy. The only network code of IAGO besides the model downloads, and it never leaves the Mac.
/// Gives "in a meeting" and "muted"; the pairing token is kept in the Keychain.
@MainActor
@Observable
final class TeamsLocalAPI {
    enum Status: Equatable {
        case off
        /// Teams does not answer: the API is off in Teams, or Teams is closed.
        case unreachable
        /// Connected, not paired yet: Teams asks the user to allow IAGO during a meeting.
        case waitingForPairing
        case connected
        case refused(String)
    }

    private(set) var status = Status.off
    private(set) var isInMeeting = false
    private(set) var isMuted = false
    @ObservationIgnored private var task: URLSessionWebSocketTask?
    @ObservationIgnored private var session: URLSession?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var requestID = 0
    private let archive: Archive
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "teams")

    static let enabledKey = "teams.localAPI"
    static let keychainAccount = "teams-local-api-token"

    init(archive: Archive) {
        self.archive = archive
    }

    var enabled: Bool {
        get { (try? archive.setting(Self.enabledKey)) == "1" }
        set {
            try? archive.setSetting(Self.enabledKey, newValue ? "1" : nil)
            newValue ? start() : stop()
        }
    }

    func start() {
        guard enabled, loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.connectAndListen()
                // Teams closed or the API off: try again later, quietly.
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        status = .off
        isInMeeting = false
        isMuted = false
    }

    private func connectAndListen() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        self.session = session
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let task = session.webSocketTask(with: TeamsMessage.url(token: Self.token, appVersion: version))
        self.task = task
        task.resume()
        do {
            try await send(TeamsMessage.queryState(requestID: nextID()))
            if status != .connected {
                status = Self.token == nil ? .waitingForPairing : .connected
                try? archive.audit(.llm, action: "teams_local_api_connected", detail: "127.0.0.1:8124")
            }
            while !Task.isCancelled {
                let message = try await task.receive()
                guard case .string(let text) = message, let parsed = TeamsMessage.parse(text) else { continue }
                apply(parsed)
            }
        } catch {
            if status == .connected || status == .waitingForPairing { logger.notice("Teams local API disconnected") }
            status = .unreachable
            isInMeeting = false
        }
        task.cancel()
        session.invalidateAndCancel()
    }

    private func apply(_ message: TeamsMessage) {
        if let token = message.tokenRefresh {
            Self.token = token
            status = .connected
            try? archive.audit(.llm, action: "teams_local_api_paired")
        }
        if let error = message.error { status = .refused(error) }
        if let inMeeting = message.isInMeeting { isInMeeting = inMeeting }
        if let muted = message.isMuted { isMuted = muted && isInMeeting }
        // Pairing happens during a meeting: asking the state makes Teams show "Allow IAGO".
        if message.canPair == true, Self.token == nil {
            Task { try? await send(TeamsMessage.queryState(requestID: nextID())) }
        }
    }

    private func send(_ text: String) async throws {
        try await task?.send(.string(text))
    }

    private func nextID() -> Int {
        requestID += 1
        return requestID
    }

    // MARK: Keychain

    static var token: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.giovannilombi.iago",
                kSecAttrAccount as String: keychainAccount, kSecReturnData as String: true,
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data
            else { return nil }
            return String(decoding: data, as: UTF8.self)
        }
        set {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.giovannilombi.iago",
                kSecAttrAccount as String: keychainAccount,
            ]
            SecItemDelete(query as CFDictionary)
            guard let newValue else { return }
            var attributes = query
            attributes[kSecValueData as String] = Data(newValue.utf8)
            attributes[kSecAttrLabel as String] = "IAGO – Teams"
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }

    func forgetPairing() {
        Self.token = nil
        if status == .connected { status = .waitingForPairing }
    }
}
