//
//  WhiteCardFlowLayout.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/3/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit

// swiftlint:disable:next identifier_name
private func easeInOut( _ t: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat) -> CGFloat {
    var t = t
    t /= d/2
    if t < 1 {
        return c/2*t*t*t + b
    }
    t -= 2
    return c/2*(t*t*t + 2) + b
}

final class WhiteCardFlowLayout: UICollectionViewFlowLayout {

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let layoutAttributes = super.layoutAttributesForElements(in: rect)
        let topContentInset = collectionView!.contentInset.top + 20
        let transitionRegion = CGFloat(120)
        for attributes in layoutAttributes! as [UICollectionViewLayoutAttributes] {
            let yOriginInSuperview = collectionView!.convert(attributes.frame.origin, to: collectionView!.superview).y
            if topContentInset > yOriginInSuperview {
                let difference = topContentInset - yOriginInSuperview
                let progress = difference/transitionRegion
                attributes.alpha = easeInOut(min(progress, 1), b: 1, c: -0.95, d: 1)
            } else {
                attributes.alpha = 1
            }
        }
        return layoutAttributes
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
}
