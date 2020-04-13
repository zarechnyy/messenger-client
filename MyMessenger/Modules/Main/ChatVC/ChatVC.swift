//
//  ChatViewController.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 3/24/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SwiftyRSA

class ChatVC: MessagesViewController {
        
    var userPubKey: String!
    var user: ServerUserModel!
    
    private var _aes: AES256!
    private var _messages: [Message] = []
    private var _socketService: SocketService = SocketService()
    
    private let _formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSocketConnection()
        configureMessageInputBar()
        configureMessageCollectionView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    func configureSocketConnection() {
        var request = URLRequest(url: URL(string: "ws://localhost:8181/ws")!)
        request.setValue("Bearer \(User.current?.token ?? "")", forHTTPHeaderField: "Authorization")
        _socketService.connect(with: request, delegate: self)
    }
    
    func configureMessageCollectionView() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self

        scrollsToBottomOnKeyboardBeginsEditing = true // default false
        maintainPositionOnKeyboardFrameChanged = true // default false
    }
    
    func configureMessageInputBar() {
        messageInputBar.delegate = self
        messageInputBar.inputTextView.tintColor = .white
        messageInputBar.sendButton.setTitleColor(.green, for: .normal)
        messageInputBar.sendButton.setTitleColor(
            UIColor.green.withAlphaComponent(0.3),
            for: .highlighted
        )
    }
    
    
    func insertMessage(_ message: Message) {
        _messages.append(message)
        
        messagesCollectionView.performBatchUpdates({
            messagesCollectionView.insertSections([_messages.count - 1])
            if _messages.count >= 2 {
                messagesCollectionView.reloadSections([_messages.count - 2])
            }
        }, completion: { [weak self] _ in
            if self?.isLastSectionVisible() == true {
                self?.messagesCollectionView.scrollToBottom(animated: true)
            }
        })
    }
    
    func isLastSectionVisible() -> Bool {
        guard !_messages.isEmpty else { return false }
        let lastIndexPath = IndexPath(item: 0, section: _messages.count - 1)
        return messagesCollectionView.indexPathsForVisibleItems.contains(lastIndexPath)
    }
}

extension ChatVC: SocketServiceDelegate {
    
    func didConnect() {
        let messegeModel = SocketMessageModel(message: "\(user.id)")
        let socketOnConnectModel = SocketResponseCommand(type: 0, model: .create(messegeModel))
        _socketService.send(socketOnConnectModel)
    }
    
    func didReceive(_ model: SocketResponseCommand) {
        switch model.type {
        case 1:
            createKey()
        case 2:
            switch model.model {
            case .key(let keyModel):
                updateKey(keyModel)
            default:
                break
            }
        case 3:
            switch model.model {
            case .messageResponse(let msg):
                updateMesseges(msg)
            default:
                break
            }
        default:
            print("Unknown command!")
            print(model)
        }
    }
 
    func didReceive(_ error: Error?) {
        guard let _ = error else { return }
    }
    
    func didDisconnect() {
        self.navigationController?.popViewController(animated: true)
    }
    
    private func createKey() {
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
            
//            let socketModel = SocketResponseCommand(type: 2, model: .key(socketKeyModel))
//            let data = try encoder.encode(socketKeyModel)
            print(socketKeyModel)
            _socketService.send(socketKeyModel)
        } catch let error {
            print(error)
        }
    }
    
    private func updateKey(_ model: SocketKeyModel) {
         do {
            guard
                let privKey = User.current?.privateKey,
                let key = decrypted(model.key, privKey, model.signatureKey),
                let iv = decrypted(model.iv, privKey, model.signatureIv),
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

    private func decrypted(_ str: String, _ privKey: String,_ sign: String) -> String? {
        do {
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

    private func updateMesseges(_ message: SocketDataStringModel) {
        do {
            guard let data = Data(base64Encoded: message.data) else {
                print("NO DATA TO SEND :(")
                return
            }
            let encrData = try _aes.decrypt(data)
            let str = String(decoding: encrData, as: UTF8.self)
            let message = Message(sender: user, messageId: UUID().uuidString, sentDate: Date(), kind: .text(str))
            insertMessage(message)
        } catch {
            print(error)
        }
    }
}

extension ChatVC: MessagesDataSource {
    func currentSender() -> SenderType {
        guard let model = CurrentUserModel.shared.model else {
            return ServerUserModel(id: -1, username: "err")
        }
        return model
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return _messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return _messages.count
    }
    
    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        if indexPath.section % 3 == 0 {
            return NSAttributedString(string: MessageKitDateFormatter.shared.string(from: message.sentDate), attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10), NSAttributedString.Key.foregroundColor: UIColor.darkGray])
        }
        return nil
    }
    
    func cellBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        
        return NSAttributedString(string: "Read", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10), NSAttributedString.Key.foregroundColor: UIColor.darkGray])
    }
    
    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(string: name, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
    }
    
    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        
        let dateString = _formatter.string(from: message.sentDate)
        return NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }
}

extension ChatVC: MessagesDisplayDelegate {
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .darkText
    }
    
    func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedString.Key: Any] {
        switch detector {
        case .hashtag, .mention: return [.foregroundColor: UIColor.blue]
        default: return MessageLabel.defaultAttributes
        }
    }
    
    func enabledDetectors(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> [DetectorType] {
        return [.url, .address, .phoneNumber, .date, .transitInformation, .mention, .hashtag]
    }

    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .red : UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)
    }
    
    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        
        let tail: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(tail, .curved)
    }
    
}

extension ChatVC: MessagesLayoutDelegate {
    
    func heightForLocation(message: MessageType,
      at indexPath: IndexPath,
      with maxWidth: CGFloat,
      in messagesCollectionView: MessagesCollectionView) -> CGFloat {
      
      return 0
    }
    
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 18
    }
    
    func cellBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 17
    }
    
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 20
    }
    
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }
    
}


extension ChatVC: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {

        let components = inputBar.inputTextView.components
        messageInputBar.inputTextView.text = String()
        messageInputBar.invalidatePlugins()

        // Send button activity animation
        messageInputBar.sendButton.startAnimating()
        messageInputBar.inputTextView.placeholder = "Sending..."
        self.messageInputBar.sendButton.stopAnimating()
        self.messageInputBar.inputTextView.placeholder = "Aa"
        guard let userModel = CurrentUserModel.shared.model else { return }
        self.insertMessages(components, userModel)
        for component in components {
            if  let str = component as? String {
                do {
                    guard let strData = str.data(using: .utf8) else { return }
                    let encrMsgData = try _aes.encrypt(strData)
                    let msgModel = SocketResponseCommand(type: 3, model: .message(SocketDataModel(data: [UInt8](encrMsgData))))
                    _socketService.send(msgModel)
                } catch {
                    print(error)
                }
            }
        }
        self.messagesCollectionView.scrollToBottom(animated: true)
    }
    
    private func insertMessages(_ data: [Any], _ user: ServerUserModel) {
        for component in data {
            if let str = component as? String {
                let message = Message(sender: user, messageId: UUID().uuidString, sentDate: Date(), kind: .text(str))
                insertMessage(message)
            }
        }
    }

}
