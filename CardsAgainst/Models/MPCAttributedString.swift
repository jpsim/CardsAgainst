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

    var mpcSerialized: Data {
        return NSKeyedArchiver.archivedData(withRootObject: attributedString)
    }

    init(attributedString: NSAttributedString) {
        self.attributedString = attributedString
    }

    init(mpcSerialized: Data) {
        let attributedString = NSKeyedUnarchiver.unarchiveObject(with: mpcSerialized) as! NSAttributedString
        self.init(attributedString: attributedString)
    }
}
