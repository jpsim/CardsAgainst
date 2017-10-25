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
    case white = "A", black = "Q"
}

struct Card: MPCSerializable {
    let content: String
    let type: CardType
    let expansion: String

    var mpcSerialized: Data {
        let dictionary = ["content": content, "type": type.rawValue, "expansion": expansion]
        return NSKeyedArchiver.archivedData(withRootObject: dictionary)
    }

    init(content: String, type: CardType, expansion: String) {
        self.content = content
        self.type = type
        self.expansion = expansion
    }

    init(mpcSerialized: Data) {
        let dict = NSKeyedUnarchiver.unarchiveObject(with: mpcSerialized) as! [String: String]
        content = dict["content"]!
        type = CardType(rawValue: dict["type"]!)!
        expansion = dict["expansion"]!
    }
}

struct CardArray: MPCSerializable {
    let array: [Card]

    var mpcSerialized: Data {
        return NSKeyedArchiver.archivedData(withRootObject: array.map { $0.mpcSerialized })
    }

    init(array: [Card]) {
        self.array = array
    }

    init(mpcSerialized: Data) {
        let dataArray = NSKeyedUnarchiver.unarchiveObject(with: mpcSerialized) as! [Data]
        array = dataArray.map { return Card(mpcSerialized: $0) }
    }
}
