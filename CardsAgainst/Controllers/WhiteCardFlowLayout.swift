//
//  WhiteCardFlowLayout.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/3/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit

private func easeInOut(var t: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat) -> CGFloat {
    t /= d/2
    if t < 1 {
        return c/2*t*t*t + b
    }
    t -= 2
    return c/2*(t*t*t + 2) + b
}

final class WhiteCardFlowLayout: UICollectionViewFlowLayout {

    override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? {
        let layoutAttributes = super.layoutAttributesForElementsInRect(rect)
        let topContentInset = collectionView!.contentInset.top + 20
        let transitionRegion = CGFloat(120)
        for attributes in layoutAttributes as! [UICollectionViewLayoutAttributes] {
            let yOriginInSuperview = collectionView!.convertPoint(attributes.frame.origin, toView: collectionView!.superview).y
            if topContentInset > yOriginInSuperview {
                let difference = topContentInset - yOriginInSuperview
                let progress = difference/transitionRegion
                attributes.alpha = easeInOut(min(progress, 1), 1, -0.95, 1)
            } else {
                attributes.alpha = 1
            }
        }
        return layoutAttributes
    }

    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        return true
    }
}
