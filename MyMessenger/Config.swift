//
//  Config.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 2/16/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation
import SwiftyRSA

public let serverPublicKey = try! PublicKey(pemEncoded: "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApgFFeAcjR/t0rqBB/PGQ6SdD46oPF6E9juQZIe7I8H+EdxWjL6L3UBWnqsXyzFsYle+VakXBba8KOec3K4FLEq9OR1upeadY+QGbgZcaCxqR3jMpx2Z6psYbNG+CcnAQAx8DAt6rHPC+SUqm7VnZLqvg9NuEZZL/pHR89vIhGkWrgvtCcetJ/LdQPwSV4lLSGv3h1OQ8+05zOwGkcBFsIWZ5sgu7XZWZ1HYhb8v+LBVkg85+W7Dap7M3I3PQj5sYea/CWGEzR7r0TIs8K/oo0aqrqOQ2Wqms5YBIeEB4b2sdkxM/He+CN5TXKJWkCfb6j5eLCuzSdveiLBnV31HotQIDAQAB\n-----END PUBLIC KEY-----")

struct Config {
    static let basePath = "http://localhost:8181/"
}
