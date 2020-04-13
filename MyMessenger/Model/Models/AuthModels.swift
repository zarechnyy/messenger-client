//
//  Networking.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 4/4/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation

struct RegistrationModel: Codable {
    let key: String
    let name: String
    let password: String
    let email: String
}

struct LoginModel: Codable {
    let password: String
    let email: String
}

struct AuthResponse: Codable {
    let token: String
    let user: ServerUserModel
}

extension EndpointCollection {
    static let login = Endpoint(method: .POST, pathEnding: "login")
    static let signup = Endpoint(method: .POST, pathEnding: "signup")
}
