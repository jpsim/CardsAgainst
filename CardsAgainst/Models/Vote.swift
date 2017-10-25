//
//  Vote.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/6/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import Foundation

struct Vote {
    let votee: Player
    let voter: Player

    static func stringFromVoteCount(_ voteCount: Int) -> String {
        switch voteCount {
        case 0:
            return "no votes"
        case 1:
            return "1 vote"
        default:
            return "\(voteCount) votes"
        }
    }
}
