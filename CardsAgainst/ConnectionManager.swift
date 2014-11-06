//
//  ConnectionManager.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/2/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import Foundation
import PeerKit
import MultipeerConnectivity

protocol MPCSerializable {
    var mpcSerialized: NSData { get }
    init(mpcSerialized: NSData)
}

enum MessageType: String {
    case EndGame = "EndGame",
    NextCard = "NextCard",
    CancelAnswer = "CancelAnswer",
    Vote = "Vote",
    Answer = "Answer",
    StartGame = "StartGame"
}

struct ConnectionManager {

    static var peers: [Player] {
        if let session = Client.sharedInstance.session {
            return (session.connectedPeers as [MCPeerID]).map { Player(peer: $0) }
        }
        return [Player]()
    }

    static var allPlayers: [Player] { return [Player.getMe()] + ConnectionManager.peers }

    static func sendMessage(type: MessageType, object: AnyObject? = nil, toPeers peers: [MCPeerID]? = Client.sharedInstance.session?.connectedPeers as [MCPeerID]?) {
        Client.sendEvent(type.rawValue, object: object, toPeers: peers)
    }
}
