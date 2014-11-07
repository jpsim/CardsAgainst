//
//  MPCAttributedString.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/3/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit

struct MPCAttributedString: MPCSerializable {
    let attributedString: NSAttributedString

    var mpcSerialized: NSData {
        return NSKeyedArchiver.archivedDataWithRootObject(attributedString)
    }

    init(attributedString: NSAttributedString) {
        self.attributedString = attributedString
    }

    init(mpcSerialized: NSData) {
        let attributedString = NSKeyedUnarchiver.unarchiveObjectWithData(mpcSerialized) as NSAttributedString
        self.init(attributedString: attributedString)
    }
}
