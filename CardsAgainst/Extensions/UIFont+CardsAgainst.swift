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

private func screenScaledFontSize(_ baseFontSize: CGFloat) -> CGFloat {
    let screenPortraitWidth = UIScreen.main.nativeBounds.size.width / UIScreen.main.nativeScale
    return baseFontSize / baseScreenWidth * screenPortraitWidth
}

extension UIFont {
    class var blackCardFont: UIFont { return UIFont.boldSystemFont(ofSize: screenScaledFontSize(35)) }
    class var whiteCardFont: UIFont { return UIFont.boldSystemFont(ofSize: screenScaledFontSize(20)) }
    class var voteButtonFont: UIFont { return UIFont.systemFont(ofSize: screenScaledFontSize(17)) }
}
