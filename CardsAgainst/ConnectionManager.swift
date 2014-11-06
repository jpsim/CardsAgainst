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

enum Event: String {
    case StartGame = "StartGame",
    Answer = "Answer",
    CancelAnswer = "CancelAnswer",
    Vote = "Vote",
    NextCard = "NextCard",
    EndGame = "EndGame"
}

struct ConnectionManager {

    // MARK: Properties

    static var peers: [MCPeerID] {
        if let session = PeerKit.session {
            return session.connectedPeers as [MCPeerID]
        }
        return [MCPeerID]()
    }

    static var otherPlayers: [Player] {
        if let session = PeerKit.session {
            return (session.connectedPeers as [MCPeerID]).map { Player(peer: $0) }
        }
        return [Player]()
    }

    static var allPlayers: [Player] { return [Player.getMe()] + ConnectionManager.otherPlayers }

    // MARK: Event Handling

    static func onEvent(event: Event, run: ObjectBlock?) {
        if let run = run {
            PeerKit.eventBlocks[event.rawValue] = run
        } else {
            PeerKit.eventBlocks.removeValueForKey(event.rawValue)
        }
    }

    // MARK: Sending

    static func sendEvent(event: Event, object: [String: MPCSerializable]? = nil, toPeers peers: [MCPeerID]? = PeerKit.session?.connectedPeers as [MCPeerID]?) {
        var anyObject: [String: NSData]?
        if let object = object {
            anyObject = [String: NSData]()
            for (key, value) in object {
                anyObject![key] = value.mpcSerialized
            }
        }
        PeerKit.sendEvent(event.rawValue, object: anyObject, toPeers: peers)
    }

    static func sendEventForEach(event: Event, objectBlock: () -> ([String: MPCSerializable])) {
        for peer in ConnectionManager.peers {
            ConnectionManager.sendEvent(event, object: objectBlock(), toPeers: [peer])
        }
    }
}
