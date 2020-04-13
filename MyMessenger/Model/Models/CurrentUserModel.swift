//
//  CurrentUserModel.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 4/9/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation

class CurrentUserModel {
    
    static let shared = CurrentUserModel()

    var model: ServerUserModel?
    
    private init() {}
}
