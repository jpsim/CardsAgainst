//
//  WhiteCardCell.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/3/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit
import Cartography

final class WhiteCardCell: UICollectionViewCell {

    class var reuseID: String { return "WhiteCardCell" }

    let label = UILabel()
    override var isHighlighted: Bool {
        get {
            return super.isHighlighted
        }
        set {
            contentView.backgroundColor = newValue ? .gray : lightColor
            super.isHighlighted = newValue
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Background
        contentView.backgroundColor = lightColor
        contentView.layer.cornerRadius = 8

        // Label
        setupLabel()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setupLabel() {
        // Label
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.font = .whiteCardFont

        // Layout
        constrain(label) { label in
            label.edges == inset(label.superview!.edges, 15, 10)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.preferredMaxLayoutWidth = label.frame.size.width
    }
}
