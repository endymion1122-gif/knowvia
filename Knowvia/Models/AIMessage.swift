import Foundation

struct AIMessage: Identifiable, Codable {
    var id = UUID()
    var role: String
    var content: String
    var createdAt = Date()

    enum CodingKeys: String, CodingKey {
        case role
        case content
    }
}
