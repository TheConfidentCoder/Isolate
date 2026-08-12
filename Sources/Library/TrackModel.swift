import Foundation
import SwiftData

@Model
final class TrackModel {
    @Attribute(.unique) var id: String
    var title: String
    var originalURL: URL
    var dateAdded: Date
    
    var vocalStemURL: URL
    var bassStemURL: URL
    var drumStemURL: URL
    var otherStemURL: URL
    
    init(id: String, title: String, originalURL: URL, dateAdded: Date = Date(), vocalStemURL: URL, bassStemURL: URL, drumStemURL: URL, otherStemURL: URL) {
        self.id = id
        self.title = title
        self.originalURL = originalURL
        self.dateAdded = dateAdded
        self.vocalStemURL = vocalStemURL
        self.bassStemURL = bassStemURL
        self.drumStemURL = drumStemURL
        self.otherStemURL = otherStemURL
    }
}
