import Foundation

public extension Data {
    /// Returns the data as a lowercase hexadecimal string.
    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }

    /// Initializes Data from a hexadecimal string. Returns nil if the string is invalid.
    init?(hexString: String) {
        let hex = hexString.replacingOccurrences(of: " ", with: "")
        guard hex.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            bytes.append(byte)
            index = nextIndex
        }
        self.init(bytes)
    }
}
