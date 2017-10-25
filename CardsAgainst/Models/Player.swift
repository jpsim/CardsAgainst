//
//  Player.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/2/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import Foundation
import MultipeerConnectivity

private let myName = UIDevice.current.name

struct Player: Hashable, Equatable, MPCSerializable {

    // MARK: Properties

    let name: String

    // MARK: Computed Properties

    var me: Bool { return name == myName }
    var displayName: String { return me ? "You" : name }
    var hashValue: Int { return name.hash }
    var mpcSerialized: Data { return name.data(using: String.Encoding.utf8)! }

    // MARK: Initializers

    init(name: String) {
        self.name = name
    }

    init(mpcSerialized: Data) {
        name = NSString(data: mpcSerialized, encoding: String.Encoding.utf8.rawValue)! as String
    }

    init(peer: MCPeerID) {
        name = peer.displayName
    }

    static func getMe() -> Player {
        return Player(name: myName)
    }

    // MARK: Methods

    func winningString() -> String {
        if me {
            return "You win this round!"
        }
        return "\(name) wins this round!"
    }

    func cardString(_ voted: Bool) -> String {
        if voted {
            return me ? "My card" : "\(name)'s card"
        }
        return me ? "Vote for my card" : "Vote for this card"
    }
}

func == (lhs: Player, rhs: Player) -> Bool {
    return lhs.name == rhs.name
}
