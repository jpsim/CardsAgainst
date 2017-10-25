//
//  PlayerCell.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/4/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit
import Cartography

final class PlayerCell: UICollectionViewCell {

    class var reuseID: String { return "PlayerCell" }
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLabel()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setupLabel() {
        // Label
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = lightColor
        label.font = .boldSystemFont(ofSize: 22)

        // Layout
        constrain(label) { label in
            label.edges == inset(label.superview!.edges, 15, 10)
        }
    }
}
