import Foundation

struct HarvestAccount: Decodable, Equatable {
    let id: Int
    let name: String
    let product: String
}
