import Foundation

/// A message of Teams' local third-party app API (ADR-0051): meeting state and the pairing token. Field names as
/// sent by Teams (`meetingUpdate.meetingState.isMuted`, `tokenRefresh`); unknown fields are ignored.
public struct TeamsMessage: Sendable, Equatable {
    public var isInMeeting: Bool?
    public var isMuted: Bool?
    public var canPair: Bool?
    public var tokenRefresh: String?
    public var error: String?

    public static func parse(_ text: String) -> TeamsMessage? {
        guard let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        var message = TeamsMessage()
        if let update = object["meetingUpdate"] as? [String: Any] {
            if let state = update["meetingState"] as? [String: Any] {
                message.isInMeeting = state["isInMeeting"] as? Bool
                message.isMuted = state["isMuted"] as? Bool
            }
            if let permissions = update["meetingPermissions"] as? [String: Any] {
                message.canPair = permissions["canPair"] as? Bool
            }
        }
        if let token = object["tokenRefresh"] as? String, !token.isEmpty { message.tokenRefresh = token }
        if let error = object["errorMsg"] as? String, !error.isEmpty { message.error = error }
        return message
    }

    /// The command that asks Teams for its state; while pairing is possible it makes Teams ask the user to allow
    /// IAGO. It changes nothing in the meeting.
    public static func queryState(requestID: Int) -> String {
        #"{"action":"query-state","parameters":{},"requestId":\#(requestID)}"#
    }

    /// The address of the API, with the token once paired.
    public static func url(token: String?, appVersion: String) -> URL {
        var components = URLComponents()
        components.scheme = "ws"
        components.host = "127.0.0.1"
        components.port = 8124
        var items: [URLQueryItem] = []
        if let token, !token.isEmpty { items.append(URLQueryItem(name: "token", value: token)) }
        items += [
            URLQueryItem(name: "protocol-version", value: "2.0.0"), URLQueryItem(name: "manufacturer", value: "IAGO"),
            URLQueryItem(name: "device", value: "Mac"), URLQueryItem(name: "app", value: "IAGO"),
            URLQueryItem(name: "app-version", value: appVersion),
        ]
        components.queryItems = items
        return components.url!
    }
}
