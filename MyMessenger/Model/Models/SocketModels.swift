//
//  Socket.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 4/22/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation

struct SocketDataModel: Codable {
    let data: [UInt8]
}

struct SocketMessageModel: Codable {
    let message: String
}

struct SocketDataStringModel: Codable {
    let data: String
}

struct SocketKeyModel: Codable {
    let key: String
    let iv: String
    var signatureKey: String = ""
    var signatureIv: String = ""
}
