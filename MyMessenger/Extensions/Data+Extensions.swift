//
//  Data+Extensions.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 4/22/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation

extension Data {
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
