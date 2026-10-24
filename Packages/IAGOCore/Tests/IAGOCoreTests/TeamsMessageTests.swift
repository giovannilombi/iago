import Foundation
import Testing

@testable import IAGOCore

@Suite struct TeamsMessageTests {
    @Test func meetingStatePairingAndErrors() {
        let update = TeamsMessage.parse(
            #"{"meetingUpdate":{"meetingState":{"isMuted":true,"isVideoOn":false,"isInMeeting":true},"meetingPermissions":{"canToggleMute":true,"canPair":true}}}"#
        )
        #expect(update == TeamsMessage(isInMeeting: true, isMuted: true, canPair: true))
        #expect(TeamsMessage.parse(#"{"tokenRefresh":"abc-123"}"#)?.tokenRefresh == "abc-123")
        #expect(TeamsMessage.parse(#"{"requestId":1,"errorMsg":"API is disabled"}"#)?.error == "API is disabled")
        #expect(TeamsMessage.parse("not json") == nil)
        let url = TeamsMessage.url(token: "t", appVersion: "0.0.1").absoluteString
        #expect(url.hasPrefix("ws://127.0.0.1:8124?token=t&protocol-version=2.0.0"))
        #expect(!TeamsMessage.url(token: nil, appVersion: "1").absoluteString.contains("token"))
        #expect(TeamsMessage.queryState(requestID: 3).contains(#""action":"query-state""#))
    }
}
