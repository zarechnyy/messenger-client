//
//  UITableViewCell+Extensions.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 3/17/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import UIKit

extension UITableViewCell {
    
    static func nib() -> UINib {
        return UINib(nibName: String(describing: self), bundle: nil)
    }
    
    static var reuseIdentifier: String {
        return String(describing: self)
    }
    
}
