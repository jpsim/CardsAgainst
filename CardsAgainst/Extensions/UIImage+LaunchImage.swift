//
//  UIImage+LaunchImage.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/5/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit

extension UIImage {
    class func launchImage() -> UIImage {
        // We only care about iOS 8+ portrait iPhones
        // LaunchImage names found here: http://stackoverflow.com/a/25843887/373262
        var launchImageName: String
        let screenHeight = UIScreen.mainScreen().bounds.size.height
        switch screenHeight {
        case 0..<568:
            // 3.5 inch screen
            launchImageName = "LaunchImage-700"
        case 568:
            // 4 inch screen
            launchImageName = "LaunchImage-700-568h"
        case 667:
            // 4.7 inch screen
            launchImageName = "LaunchImage-800-667h"
        case 736:
            // 5.5 inch screen
            launchImageName = "LaunchImage-800-Portrait-736h"
        case 1024:
            // iPads, ev'ry last one of 'em
            launchImageName = "LaunchImage-700-Portrait@2x~ipad"
        default:
            fatalError("Unable to find a LaunchImage for this device's screen size (height of \(screenHeight)pt).  UIImage+LaunchImage likely needs to be updated.")
        }
        return UIImage(named: launchImageName)!
    }
}
