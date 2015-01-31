//
//  UIFont+CardsAgainst.swift
//  CardsAgainst
//
//  Created by Cap'n Slipp on 12/1/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit

/// The screen width the base font sizes are designed for.
private let baseScreenWidth: CGFloat = 375

private func screenScaledFontSize(baseFontSize: CGFloat) -> CGFloat {
    let screenPortraitWidth = UIScreen.mainScreen().nativeBounds.size.width / UIScreen.mainScreen().nativeScale
    return baseFontSize / baseScreenWidth * screenPortraitWidth
}

extension UIFont {
    class var blackCardFont: UIFont { return UIFont.boldSystemFontOfSize(screenScaledFontSize(35)) }
    class var whiteCardFont: UIFont { return UIFont.boldSystemFontOfSize(screenScaledFontSize(20)) }
    class var voteButtonFont: UIFont { return UIFont.systemFontOfSize(screenScaledFontSize(17)) }
}
