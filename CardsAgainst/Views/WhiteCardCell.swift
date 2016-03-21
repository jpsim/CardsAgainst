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
    override var highlighted: Bool {
        get {
            return super.highlighted
        }
        set {
            contentView.backgroundColor = newValue ? UIColor.grayColor() : lightColor
            super.highlighted = newValue
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

    private func setupLabel() {
        // Label
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .ByWordWrapping
        label.font = UIFont.whiteCardFont

        // Layout
        constrain(label) { label in
            label.edges == inset(label.superview!.edges, 15, 10); return
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.preferredMaxLayoutWidth = label.frame.size.width
    }
}
