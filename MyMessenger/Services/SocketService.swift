//
//  SocketService.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 4/13/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation
import Starscream

protocol SocketServiceDelegate: AnyObject {
    func didConnect()
    func didReceive(_ error: Error?)
    func didReceive(_ model: SocketResponseCommand)
    func didDisconnect()
}

class SocketService {
    
    weak var delegate: SocketServiceDelegate?
    
    private var _webSocket: WebSocket!
    private var _request: URLRequest!
    private let _encoder: JSONEncoder = JSONEncoder()
    
    
    func connect(with request: URLRequest, delegate: SocketServiceDelegate) {
        self._request = request
        self._webSocket = WebSocket(request: request)
        self.delegate = delegate
        
        _webSocket.delegate = self
        _webSocket.connect()
    }
    
    func send<T: Encodable>(_ model: T) {
        do {
            print(model)
            let data = try _encoder.encode(model)
            _webSocket.write(data: data, completion: nil)
        } catch {
            delegate?.didReceive(error)
        }
    }
}

extension SocketService: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        print(event)
        switch event {
        case .text(let message):
            print(message)
            do {
                let decoder = JSONDecoder()
                let jsonData = Data(message.utf8)
                let model = try decoder.decode(SocketResponseCommand.self, from: jsonData)
                print(model)
                delegate?.didReceive(model)
            } catch let error {
                print(error)
            }
        case .connected(_):
            delegate?.didConnect()
        case .error(let error):
            delegate?.didReceive(error)
        case .disconnected(_, _):
            delegate?.didDisconnect()
        default:
            break
        }
    }
}
