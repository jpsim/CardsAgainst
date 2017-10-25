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
        super.init(frame: frame)
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setLastTokenAlpha(_ alpha: CGFloat) {
        if let lastRange = placeholderRanges.last,
            let mAttributedText = attributedText?.mutableCopy() as? NSMutableAttributedString {
            mAttributedText.addAttribute(.foregroundColor, value: tintColor.withAlphaComponent(alpha), range: lastRange)
            attributedText = mAttributedText
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        setLastTokenAlpha(0.5)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        setLastTokenAlpha(1)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        setLastTokenAlpha(1)
    }
}
