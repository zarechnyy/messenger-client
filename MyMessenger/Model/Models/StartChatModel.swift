//
//  StartChatModel.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 4/4/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation

struct StartChatModel: Codable {
    let id: Int
}

struct StartChatResponse: Codable {
    let key: String
    let signature: String
}

extension EndpointCollection {
    static let startChat = Endpoint(method: .POST, pathEnding: "chat")
}
