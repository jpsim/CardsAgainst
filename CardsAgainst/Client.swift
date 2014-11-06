//
//  Client.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/3/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import Foundation
import MultipeerConnectivity

public typealias PeerBlock = ((peerID: MCPeerID) -> Void)
public typealias EventBlock = ((peerID: MCPeerID, event: String, object: AnyObject?) -> Void)
public typealias ObjectBlock = ((peerID: MCPeerID, object: AnyObject?) -> Void)

public class Client {
    public let transceiver = Transceiver()
    public var session: MCSession?

    public var onConnect: PeerBlock?
    public var onDisconnect: PeerBlock?
    public var onEvent: EventBlock?
    public var onEventObject: ObjectBlock?
    public var eventBlocks = [String: ObjectBlock]()

    public class var sharedInstance: Client {
        struct Static {
            static let instance: Client = Client()
        }
        return Static.instance
    }

    init() {
        NSNotificationCenter.defaultCenter().addObserverForName("connected", object: nil, queue: nil) { note in
            let peerID = note.object!["peerID"] as MCPeerID
            if self.session == nil {
                self.session = self.transceiver.sessionForPeer(peerID)
            }
            if let onConnect = self.onConnect {
                dispatch_async(dispatch_get_main_queue()) {
                    onConnect(peerID: peerID)
                }
            }
        }
        NSNotificationCenter.defaultCenter().addObserverForName("disconnected", object: nil, queue: nil) { note in
            if let onDisconnect = self.onDisconnect {
                let peerID = note.object!["peerID"] as MCPeerID
                dispatch_async(dispatch_get_main_queue()) {
                    onDisconnect(peerID: peerID)
                }
            }
        }
        NSNotificationCenter.defaultCenter().addObserverForName("data", object: nil, queue: nil) { note in
            let dict = NSKeyedUnarchiver.unarchiveObjectWithData(note.object!["data"] as NSData) as [String: AnyObject]
            let peerID = note.object!["peerID"] as MCPeerID
            let event = dict["event"] as String
            let object: AnyObject? = dict["object"]
            dispatch_async(dispatch_get_main_queue()) {
                if let onEvent = self.onEvent {
                    onEvent(peerID: peerID, event: event, object: object)
                }
                if let eventBlock = self.eventBlocks[event] {
                    eventBlock(peerID: peerID, object: object)
                }
            }
        }
    }

    // MARK: Advertise/Browse

    public func transceive(serviceType: String, discoveryInfo: [String: String]? = nil) {
        transceiver.startTransceiving(serviceType: serviceType, discoveryInfo: discoveryInfo)
    }

    public func advertise(serviceType: String, discoveryInfo: [String: String]? = nil) {
        transceiver.startAdvertising(serviceType: serviceType, discoveryInfo: discoveryInfo)
    }

    public func browse(serviceType: String) {
        transceiver.startBrowsing(serviceType: serviceType)
    }

    // MARK: Events

    public class func sendEvent(event: String, object: AnyObject? = nil, toPeers peers: [MCPeerID]? = Client.sharedInstance.session?.connectedPeers as [MCPeerID]?) {
        if peers == nil {
            return
        }
        var rootObject: [String: AnyObject] = ["event": event]
        if object != nil {
            rootObject["object"] = object!
        }
        let data = NSKeyedArchiver.archivedDataWithRootObject(rootObject)
        sharedInstance.session?.sendData(data, toPeers: peers, withMode: .Reliable, error: nil)
    }
}
