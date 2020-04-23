//
//  SocketModels.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 4/8/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation

struct SocketResponseCommandModel: Codable {
    var type: Int
    var model: Model
    
    init(type: Int, model: Model) {
        self.type = type
        self.model = model
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Int.self, forKey: .type)
        self.type = type
        switch type {
        case -1, 0, 1, 5:
            let payload = try container.decode(SocketMessageModel.self, forKey: .model)
            self.model = .create(payload)
        case 2:
            let payload = try container.decode(SocketKeyModel.self, forKey: .model)
            self.model = .key(payload)
        case 3:
            let payload = try container.decode(SocketDataStringModel.self, forKey: .model)
            self.model = .messageResponse(payload)
        case 6:
            let payload = try container.decode(UserModelResponse.self, forKey: .model)
            self.model = .users(payload)
        default:
            self.model = .unsupported
        }
    }
}

enum Model: Codable {
    case create(SocketMessageModel)
    case key(SocketKeyModel)
    case message(SocketDataModel)
    case messageResponse(SocketDataStringModel)
    case users(UserModelResponse)
    case unsupported
}

extension Model {
    private enum CodingKeys: String, CodingKey {
        case message
        case key
        case data
        case type
        case iv
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .message(let model):
            try container.encode(model.data, forKey: .data)
        case .create(let model):
            try container.encode(model.message, forKey: .message)
        case .key(let model):
            try container.encode(model.key, forKey: .key)
            try container.encode(model.iv, forKey: .iv)
        case .unsupported:
            let context = EncodingError.Context(codingPath: [], debugDescription: "Invalid attachment.")
            throw EncodingError.invalidValue(self, context)
        default: break
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Int.self, forKey: .type)
        switch type {
        case 0:
            let payload = try container.decode(SocketMessageModel.self, forKey: .message)
            self = .create(payload)
        case 1:
            let payload = try container.decode(SocketMessageModel.self, forKey: .key)
            self = .create(payload)
        case 2:
            let payload = try container.decode(SocketKeyModel.self, forKey: .key)
            self = .key(payload)
        case 3:
            let payload = try container.decode(SocketDataModel.self, forKey: .key)
            self = .message(payload)
        default:
            self = .unsupported
        }
    }
}
