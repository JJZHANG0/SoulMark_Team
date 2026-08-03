//
//  Item.swift
//  SoulMark
//
//  Created by JJ Zhang on 2026/8/3.
//

import Foundation

final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

final class SoulMarkRecord: Identifiable {
    let id = UUID()
    var createdAt: Date
    var kind: String
    var title: String
    var content: String
    var mood: String?

    init(kind: String, title: String, content: String, mood: String? = nil, createdAt: Date = .now) {
        self.createdAt = createdAt
        self.kind = kind
        self.title = title
        self.content = content
        self.mood = mood
    }
}

final class ConnectionProfile: Identifiable {
    let id = UUID()
    var createdAt: Date
    var name: String
    var relationship: String
    var notes: String
    var closeness: Int

    init(name: String, relationship: String, notes: String = "", closeness: Int = 3) {
        self.createdAt = .now
        self.name = name
        self.relationship = relationship
        self.notes = notes
        self.closeness = closeness
    }
}
