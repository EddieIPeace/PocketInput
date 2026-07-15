import Foundation

public enum ProtocolConstants {
    public static let protocolVersion = 1
    /// Bonjour / DNS-SD service type (includes leading underscore and `._tcp`).
    public static let bonjourServiceType = "_pocketinput._tcp"
    public static let lineDelimiter = UInt8(0x0A) // \n
}
