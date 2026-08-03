//
//  Item.swift
//  SoulMark
//
//  Created by JJ Zhang on 2026/8/3.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
