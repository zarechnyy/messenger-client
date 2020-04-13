//
//  User.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 2/16/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation
import SwiftKeychainWrapper

struct UserModel {
    let login: String
    let password: String
    let token: String
    var publicKey: String? = nil
    var privateKey: String? = nil
}

fileprivate enum UserKeys: String {
    case login
    case password
    case token
    case publicKey
    case privateKey
}

struct User {
        
    static private var _current: UserModel?
    static var current: UserModel? {
        guard let cachedUser = _current else {
            if let login = KeychainWrapper.standard.string(forKey: UserKeys.login.rawValue),
                let password = KeychainWrapper.standard.string(forKey: UserKeys.password.rawValue),
                let token = KeychainWrapper.standard.string(forKey: UserKeys.token.rawValue) {
                _current = UserModel(login: login, password: password, token: token)
                if let publicKey = KeychainWrapper.standard.string(forKey: UserKeys.publicKey.rawValue),
                    let privateKey = KeychainWrapper.standard.string(forKey: UserKeys.privateKey.rawValue) {
                    _current?.publicKey = publicKey
                    _current?.privateKey = privateKey
                }
            }
            return _current
        }
        return cachedUser
    }
    
    
    // MARK: - Update
    
    @discardableResult
    static func update(login: String) -> Bool {
        defer {
            _current = nil
        }
        return KeychainWrapper.standard.set(login, forKey: UserKeys.login.rawValue)
    }
    
    @discardableResult
    static func update(password: String) -> Bool {
        defer {
            _current = nil
        }
        return KeychainWrapper.standard.set(password, forKey: UserKeys.password.rawValue)
    }
    
    @discardableResult
    static func update(token: String) -> Bool {
        defer {
            _current = nil
        }
        return KeychainWrapper.standard.set(token, forKey: UserKeys.token.rawValue)
    }
    
    
    // MARK: - Save / Clear
    
    @discardableResult
    static func save(model: UserModel) -> Bool {
        var saveSuccessful = true
        saveSuccessful = saveSuccessful && KeychainWrapper.standard.set(model.login, forKey: UserKeys.login.rawValue)
        saveSuccessful = saveSuccessful && KeychainWrapper.standard.set(model.password, forKey: UserKeys.password.rawValue)
        saveSuccessful = saveSuccessful && KeychainWrapper.standard.set(model.token, forKey: UserKeys.token.rawValue)
        if let pubKey = model.publicKey, let privKey = model.privateKey {
            saveSuccessful = saveSuccessful && KeychainWrapper.standard.set(pubKey, forKey: UserKeys.publicKey.rawValue)
            saveSuccessful = saveSuccessful && KeychainWrapper.standard.set(privKey, forKey: UserKeys.privateKey.rawValue)
        }
        if saveSuccessful {
            _current = model
        }
        return saveSuccessful
    }
    
    @discardableResult
    static func clear() -> Bool {
        var clearSuccessful = true
        clearSuccessful = clearSuccessful && KeychainWrapper.standard.removeObject(forKey: UserKeys.login.rawValue)
        clearSuccessful = clearSuccessful && KeychainWrapper.standard.removeObject(forKey: UserKeys.password.rawValue)
        clearSuccessful = clearSuccessful && KeychainWrapper.standard.removeObject(forKey: UserKeys.token.rawValue)
        clearSuccessful = clearSuccessful && KeychainWrapper.standard.removeObject(forKey: UserKeys.publicKey.rawValue)
        clearSuccessful = clearSuccessful && KeychainWrapper.standard.removeObject(forKey: UserKeys.privateKey.rawValue)
        return clearSuccessful
    }
    
}
