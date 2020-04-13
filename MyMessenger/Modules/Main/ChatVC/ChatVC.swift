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
import Starscream
import SwiftyRSA

class ChatVC: MessagesViewController {
        
    var userPubKey: String!
    var user: ServerUserModel!
    var messages: [Message] = []
    var socket: WebSocket!
    var aes: AES256!
    let refreshControl = UIRefreshControl()
    let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSocketConnection()
        configureMessageInputBar()
        configureMessageCollectionView()
        loadFirstMessages()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    func configureSocketConnection() {
        var request = URLRequest(url: URL(string: "ws://localhost:8181/ws")!)
        request.setValue("Bearer \(User.current?.token ?? "")", forHTTPHeaderField: "Authorization")
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
    }
    
    func configureMessageCollectionView() {
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messageCellDelegate = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self

        scrollsToBottomOnKeyboardBeginsEditing = true // default false
        maintainPositionOnKeyboardFrameChanged = true // default false
        
        messagesCollectionView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(loadMoreMessages), for: .valueChanged)
    }
    
    @objc func loadMoreMessages() {

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
    
    func loadFirstMessages() {
//        let user = UserKek(senderId: "kkk", displayName: "owowo")
//        let message = Message(sender: user, messageId: UUID().uuidString, user: user, sentDate: Date(), kind: .text("ekekowowowl"), text: "ekekowowowl")
//        let msgs = [message, message, message, message, message, message]
//        self.messages = msgs
//        DispatchQueue.global(qos: .userInitiated).async {
//            let count = UserDefaults.standard.mockMessagesCount()
//            SampleData.shared.getMessages(count: count) { messages in
//                DispatchQueue.main.async {
//                    self.messageList = messages
                    self.messagesCollectionView.reloadData()
                    self.messagesCollectionView.scrollToBottom()
//                }
//            }
//        }
    }

    
    func insertMessage(_ message: Message) {
        messages.append(message)
        // Reload last section to update header/footer labels and insert a new one
        messagesCollectionView.performBatchUpdates({
            messagesCollectionView.insertSections([messages.count - 1])
            if messages.count >= 2 {
                messagesCollectionView.reloadSections([messages.count - 2])
            }
        }, completion: { [weak self] _ in
            if self?.isLastSectionVisible() == true {
                self?.messagesCollectionView.scrollToBottom(animated: true)
            }
        })
    }
    
    func isLastSectionVisible() -> Bool {
        
        guard !messages.isEmpty else { return false }
        
        let lastIndexPath = IndexPath(item: 0, section: messages.count - 1)
        
        return messagesCollectionView.indexPathsForVisibleItems.contains(lastIndexPath)
    }
    
}

extension ChatVC: WebSocketDelegate {
    
    
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        print(event)
        switch event {
        case .viablityChanged(let state):
            if state {
                let messegeModel = SocketMessageModel(message: "\(user.id)")
                let socketModel = SocketResponseCommand(type: 0, model: .create(messegeModel))
                let encoder = JSONEncoder()
                let data = try! encoder.encode(socketModel)
                print(String(decoding: data, as: UTF8.self))
                socket.write(data: data, completion: nil)
            }
        case .text(let str):
            let decoder = JSONDecoder()
            let jsonData = Data(str.utf8)
            do {
                let model = try decoder.decode(SocketResponseCommand.self, from: jsonData)
                print(model)
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
            } catch let error {
                print(error)
            }
        case .disconnected(let str, let code):
            self.navigationController?.popViewController(animated: true)
            print(str)
            print(code)
        default:
            break
        }
    }
    
    private func createKey() {
        do {
            let pw = "myAwesomePassword"
            let salt = AES256.randomSalt()
            let iv = AES256.randomIv()
            let key = try AES256.createKey(password: pw.data(using: .utf8)!, salt: salt)
            aes = try AES256(key: key, iv: iv)
            
            let encoder = JSONEncoder()
            let encrKeys = encrypted(key.hexString, userPubKey)
            let ecnrIvs = encrypted(iv.hexString, userPubKey)
            guard let encrKey = encrKeys.0, let encrSign = encrKeys.1 else { return }
            guard let encrIv = ecnrIvs.0, let encrIvSign = ecnrIvs.1 else { return }
            
            var socketKeyModel = SocketKeyModel(key: encrKey, iv: encrIv)
            socketKeyModel.signatureKey = encrSign
            socketKeyModel.signatureIv = encrIvSign
            
            let socketModel = SocketResponseCommand(type: 2, model: .key(socketKeyModel))
            let data = try encoder.encode(socketKeyModel)
            print(socketModel)
            socket.write(data: data, completion: nil)
        } catch let error {
            print(error)
        }
    }
    
    private func updateKey(_ model: SocketKeyModel) {
         do {
            guard let privKey = User.current?.privateKey else { return }
            guard let key = decrypted(model.key, privKey, model.signatureKey) else { return }
            guard let iv = decrypted(model.iv, privKey, model.signatureIv) else { return }
            guard let keyData = key.dataFromHexadecimalString(), let ivData = iv.dataFromHexadecimalString() else { return }
            aes = try AES256(key: keyData, iv: ivData)
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
        print(message.data)
        do {
            guard let data = Data(base64Encoded: message.data) else {
                print("NO DATA(((")
                return
            }
            let encrData = try aes.decrypt(data)
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
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
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
        
        let dateString = formatter.string(from: message.sentDate)
        return NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }
    


}

extension ChatVC: MessageCellDelegate {
    
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
//    
//    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
////        let avatar = SampleData.shared.getAvatarFor(sender: message.sender)
//        avatarView.set(avatar: <#T##Avatar#>)
//    }
    
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

        // Here we can parse for which substrings were autocompleted
        let attributedText = messageInputBar.inputTextView.attributedText!
        let range = NSRange(location: 0, length: attributedText.length)
        attributedText.enumerateAttribute(.autocompleted, in: range, options: []) { (_, range, _) in

            let substring = attributedText.attributedSubstring(from: range)
            let context = substring.attribute(.autocompletedContext, at: 0, effectiveRange: nil)
            
//            socket.write(data: <#T##Data#>, completion: <#T##(() -> ())?##(() -> ())?##() -> ()#>)
//            print("Autocompleted: `", substring, "` with context: ", context ?? [])
        }

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
                    let encoder = JSONEncoder()
                    
                    guard let strData = str.data(using: .utf8) else { return }
                    
                    let encrMsgData = try aes.encrypt(strData)
                    let msgModel = SocketResponseCommand(type: 3, model: .message(SocketDataModel(data: [UInt8](encrMsgData))))
                    let data = try encoder.encode(msgModel)
                    print(msgModel)
                    self.socket.write(data: data, completion: nil)
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
