//
//  MessageProcessService.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 4/23/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation
import SwiftyRSA

protocol MessageProcessServiceDelegate: AnyObject {
    func didReceiveNew(_ message: String)
    func shouldSend<T: Encodable>(_ model: T)
}

final class MessageProcessService {

    private var _aes: AES256!
    private let userPubKey: String

    weak var delegate: MessageProcessServiceDelegate?

    init(userPubKey: String) {
        self.userPubKey = userPubKey
    }

    func createKey() {
        do {
            let pw = "myAwesomePassword"
            let salt = AES256.randomSalt()
            let iv = AES256.randomIv()
            let key = try AES256.createKey(password: pw.data(using: .utf8)!, salt: salt)
            _aes = try AES256(key: key, iv: iv)
            
            let encrKeys = encrypted(key.hexString, userPubKey)
            let ecnrIvs = encrypted(iv.hexString, userPubKey)
            guard let encrKey = encrKeys.0, let encrSign = encrKeys.1 else { return }
            guard let encrIv = ecnrIvs.0, let encrIvSign = ecnrIvs.1 else { return }
            
            var socketKeyModel = SocketKeyModel(key: encrKey, iv: encrIv)
            socketKeyModel.signatureKey = encrSign
            socketKeyModel.signatureIv = encrIvSign
            print(socketKeyModel)
            delegate?.shouldSend(socketKeyModel)

        } catch let error {
            print(error)
        }
    }
       
    func updateKey(_ model: SocketKeyModel) {
        do {
           guard
               let key = decrypted(model.key, model.signatureKey),
               let iv = decrypted(model.iv, model.signatureIv),
               let keyData = key.dataFromHexadecimalString(),
               let ivData = iv.dataFromHexadecimalString() else {
                   assertionFailure("CANT UPDATE AES KEY!")
                   return
               }
            
           _aes = try AES256(key: keyData, iv: ivData)
        } catch let error {
           print(error)
        }
    }

    func decryptMessege(_ message: SocketDataStringModel) {
        do {
            guard let data = Data(base64Encoded: message.data) else {
                print("NO DATA TO SEND :(")
                return
            }
            
            let encrData = try _aes.decrypt(data)
            let message = String(decoding: encrData, as: UTF8.self)
            delegate?.didReceiveNew(message)
    //           let message = Message(sender: user, messageId: UUID().uuidString, sentDate: Date(), kind: .text(str))
    //           insertMessage(message)
       } catch {
           print(error)
       }
    }
    
    func encryptMessege(_ message: String) {
        do {
            guard let messageData = message.data(using: .utf8) else { return }
            let encrMsgData = try _aes.encrypt(messageData)
            
            let messageModel = SocketResponseCommandModel(type: 3, model: .message(SocketDataModel(data: [UInt8](encrMsgData))))
            delegate?.shouldSend(messageModel)
       } catch {
           print(error)
       }
    }

    private func encrypted(_ str: String,_ pubBKey: String) -> (String?, String?) {
        do {
            let clearStr = try ClearMessage(string: str, using: .utf8)
       
            guard let privKey = User.current?.privateKey else { return (nil, nil) }
            let userAPrivateKey = try PrivateKey(pemEncoded: privKey)
            let sign = try clearStr.signed(with: userAPrivateKey, digestType: .sha256)
           
            let clientPubKey = try PublicKey(pemEncoded: pubBKey)
            let encrStr = try clearStr.encrypted(with: clientPubKey, padding: .PKCS1)
           
            return (encrStr.base64String, sign.base64String)
        } catch let err {
            print(err)
            return (nil, nil)
        }
    }

    private func decrypted(_ str: String,_ sign: String) -> String? {
        do {
            guard let privKey = User.current?.privateKey else { return nil}
            let privateKey = try PrivateKey(pemEncoded: privKey)
            let encryptedStr = try EncryptedMessage(base64Encoded: str)
            let decrStr = try encryptedStr.decrypted(with: privateKey, padding: .PKCS1)
       
            let signature = try Signature(base64Encoded: sign)
            let pubKey = try PublicKey(pemEncoded: userPubKey)
            let isSuccess = try decrStr.verify(with: pubKey, signature: signature, digestType: .sha256)
           
            return isSuccess ? try decrStr.string(encoding: .utf8) : nil
        } catch let err {
            print(err)
            return nil
        }
    }
}
