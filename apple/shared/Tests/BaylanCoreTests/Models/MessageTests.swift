import Testing
import Foundation
@testable import BaylanCore

@Suite("Message")
struct MessageTests {

    @Test("Message id matches messageId")
    func idMatchesMessageId() {
        let msg = Message(
            threadId: UUID(),
            senderId: "sender",
            recipientId: "recipient",
            body: "Hello",
            type: .text
        )
        #expect(msg.id == msg.messageId)
    }

    @Test("Message round-trips through Codable")
    func codableRoundTrip() throws {
        let original = Message(
            threadId: UUID(),
            senderId: "alice",
            recipientId: "bob",
            body: "Test",
            type: .text,
            state: .delivered,
            hopCount: 2
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        #expect(decoded.messageId == original.messageId)
        #expect(decoded.body == original.body)
        #expect(decoded.state == original.state)
        #expect(decoded.hopCount == original.hopCount)
    }
}
