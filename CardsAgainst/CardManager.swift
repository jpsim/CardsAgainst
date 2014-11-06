//
//  CardManager.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/2/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import Foundation

private let (blackCards, whiteCards) = ({
    let jsonPath = NSBundle.mainBundle().pathForResource("cards", ofType: "json")
    let cards = NSJSONSerialization.JSONObjectWithData(NSData(contentsOfFile: jsonPath!)!, options: nil, error: nil) as [[String: String]]

    var whiteCards = [Card]()
    var blackCards = [Card]()

    for card in cards {
        let card = Card(content: card["text"]!,
            type: CardType(rawValue: card["cardType"]!)!,
            expansion: card["expansion"]!)
        if card.type == .White {
            whiteCards.append(card)
        } else {
            blackCards.append(card)
        }
    }

    return (blackCards, whiteCards)
} as () -> ([Card], [Card]))()

private var (mWhiteCards, mBlackCards) = ([Card](), [Card]())

struct CardManager {
    static func nextCardsWithType(type: CardType, count: UInt = 1) -> [Card] {
        let generator = Array(count: Int(count), repeatedValue: 0)
        if type == .Black {
            return generator.map { _ in return self.takeRandom(&mBlackCards, original: blackCards) }
        } else {
            return generator.map { _ in return self.takeRandom(&mWhiteCards, original: whiteCards) }
        }
    }

    private static func takeRandom<U>(inout mutable: [U], original: [U]) -> U {
        if mutable.count == 0 {
            // reshuffle
            mutable = original.sorted { _, _ in arc4random() % 2 == 0 }
        }
        return mutable.removeLast()
    }
}
