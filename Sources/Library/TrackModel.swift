import Foundation
import SwiftData

@Model
public final class TrackModel {
    @Attribute(.unique) public var id: String
    public var title: String
    public var originalURL: URL
    public var dateAdded: Date
    
    public var vocalStemURL: URL
    public var bassStemURL: URL
    public var drumStemURL: URL
    public var otherStemURL: URL
    
    public init(id: String, title: String, originalURL: URL, dateAdded: Date = Date(), vocalStemURL: URL, bassStemURL: URL, drumStemURL: URL, otherStemURL: URL) {
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
