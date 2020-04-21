//
//  UserModel.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 4/4/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation
import MessageKit

struct UserModelResponse: Codable {
    let users: [ServerUserModel]
}

struct ServerUserModel: Codable, SenderType {
    var senderId: String {
        return String(id)
    }
    
    var displayName: String {
        return username
    }
    
    let id: Int
    let username: String
    
    var isOnline: Bool = false
    
    mutating func setOffline() {
        isOnline = false
    }
    
    mutating func setOnline() {
        isOnline = true
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, username
    }
}

extension EndpointCollection {
    static let getAllUsers = Endpoint(method: .GET, pathEnding: "users")
}
