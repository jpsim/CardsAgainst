//
//  TouchableLabel.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/3/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit

final class TouchableLabel: UILabel {
    var placeholderRanges = [NSRange]()

    override init(frame: CGRect) {
        super.init(frame: CGRectZero)
        userInteractionEnabled = true
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setLastTokenAlpha(alpha: CGFloat) {
        if let lastRange = placeholderRanges.last {
            let mAttributedText = attributedText.mutableCopy() as! NSMutableAttributedString
            mAttributedText.addAttribute(NSForegroundColorAttributeName, value: tintColor.colorWithAlphaComponent(alpha), range: lastRange)
            attributedText = mAttributedText
        }
    }

    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        setLastTokenAlpha(0.5)
    }

    override func touchesCancelled(touches: Set<NSObject>!, withEvent event: UIEvent!) {
        setLastTokenAlpha(1)
    }

    override func touchesEnded(touches: Set<NSObject>, withEvent event: UIEvent) {
        setLastTokenAlpha(1)
    }
}
