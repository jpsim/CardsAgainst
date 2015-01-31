//
//  Card.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/2/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import Foundation

let blackCardPlaceholder = "________"

enum CardType: String {
    case White = "A", Black = "Q"
}

struct Card: MPCSerializable {
    let content: String
    let type: CardType
    let expansion: String

    var mpcSerialized: NSData {
        return NSKeyedArchiver.archivedDataWithRootObject(["content": content, "type": type.rawValue, "expansion": expansion])
    }

    init(content: String, type: CardType, expansion: String) {
        self.content = content
        self.type = type
        self.expansion = expansion
    }

    init(mpcSerialized: NSData) {
        let dict = NSKeyedUnarchiver.unarchiveObjectWithData(mpcSerialized) as [String: String]
        content = dict["content"]!
        type = CardType(rawValue: dict["type"]!)!
        expansion = dict["expansion"]!
    }
}

struct CardArray: MPCSerializable {
    let array: Array<Card>

    var mpcSerialized: NSData {
        return NSKeyedArchiver.archivedDataWithRootObject(array.map { $0.mpcSerialized })
    }

    init(array: Array<Card>) {
        self.array = array
    }

    init(mpcSerialized: NSData) {
        let dataArray = NSKeyedUnarchiver.unarchiveObjectWithData(mpcSerialized) as [NSData]
        array = dataArray.map { return Card(mpcSerialized: $0) }
    }
}
