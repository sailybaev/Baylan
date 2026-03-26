import Testing
import Foundation
@testable import BaylanCore

@Suite("SeenSet")
struct SeenSetTests {

    @Test("Contains returns false for unknown message ID")
    func unknownId() async {
        let set = SeenSet()
        let result = await set.contains("unknown-id")
        #expect(result == false)
    }

    @Test("Contains returns true after insert")
    func insertAndContains() async {
        let set = SeenSet()
        await set.insert("msg-1")
        let result = await set.contains("msg-1")
        #expect(result == true)
    }

    @Test("Duplicate insert does not crash")
    func duplicateInsert() async {
        let set = SeenSet()
        await set.insert("msg-1")
        await set.insert("msg-1")
        let result = await set.contains("msg-1")
        #expect(result == true)
    }

    @Test("Different IDs are tracked independently")
    func multipleIds() async {
        let set = SeenSet()
        await set.insert("msg-1")
        await set.insert("msg-2")
        let has1 = await set.contains("msg-1")
        let has2 = await set.contains("msg-2")
        let has3 = await set.contains("msg-3")
        #expect(has1 == true)
        #expect(has2 == true)
        #expect(has3 == false)
    }
}
