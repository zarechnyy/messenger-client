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
        
    var user: ServerUserModel!
    var messageProcessService: MessageProcessService!
    var isChatStarted: Bool = false
    
    private var _messages: [Message] = []
    private var _socketService: SocketService = SocketService()
    
    private let _formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messageProcessService.delegate = self
        configureSocketConnection()
        
        configureMessageInputBar()
        configureMessageCollectionView()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(close))
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
        DispatchQueue.main.async {
            self._messages.append(message)
    
            self.messagesCollectionView.performBatchUpdates({
                self.messagesCollectionView.insertSections([self._messages.count - 1])
                if self._messages.count >= 2 {
                    self.messagesCollectionView.reloadSections([self._messages.count - 2])
                }
            }, completion: { [weak self] _ in
                if self?.isLastSectionVisible() == true {
                    self?.messagesCollectionView.scrollToBottom(animated: true)
                }
            })
        }
    }
    
    func isLastSectionVisible() -> Bool {
        guard !_messages.isEmpty else { return false }
        let lastIndexPath = IndexPath(item: 0, section: _messages.count - 1)
        return messagesCollectionView.indexPathsForVisibleItems.contains(lastIndexPath)
    }
    
    @objc func close() {
        _socketService.close()
        self.navigationController?.popViewController(animated: true)
    }
}

extension ChatVC: SocketServiceDelegate {
    
    func didConnect() {
        let messegeModel = SocketMessageModel(message: "\(user.id)")
        let socketOnConnectModel = SocketResponseCommandModel(type: 0, model: .create(messegeModel))
        _socketService.send(socketOnConnectModel)
    }
    
    func didReceive(_ model: SocketResponseCommandModel) {
        switch model.type {
        case -1:
            let model = SocketResponseCommandModel(type: -1, model: .create(SocketMessageModel(message: "pong")))
            _socketService.send(model)
            isChatStarted = true
        case 1:
            messageProcessService.createKey()
        case 2:
            switch model.model {
            case .key(let keyModel):
                messageProcessService.updateKey(keyModel)
                isChatStarted = true
            default:
                break
            }
        case 3:
            switch model.model {
            case .messageResponse(let msg):
                messageProcessService.decryptMessege(msg)
            default:
                break
            }
        case 5:
            switch model.model {
            case .create(_):
                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: true)
                }
            default: break
            }
        default:
            print("Unknown command!")
        }
    }
 
    func didReceive(_ error: Error?) {
        guard let _ = error else { return }
    }
    
    func didDisconnect() {
        _socketService.close()
        DispatchQueue.main.async {
            self.navigationController?.popViewController(animated: true)
        }
    }
}

extension ChatVC: MessageProcessServiceDelegate {
    func didReceiveNew(_ message: String) {
        let message = Message(sender: self.user, messageId: UUID().uuidString, sentDate: Date(), kind: .text(message))
        self.insertMessage(message)
    }
    
    func shouldSend<T>(_ model: T) where T : Encodable {
        _socketService.send(model)
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
        if isChatStarted {
            
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
                    messageProcessService.encryptMessege(str)
                }
            }
            self.messagesCollectionView.scrollToBottom(animated: true)
        } else {
            
            let alert = UIAlertController(title: "Chat is not started", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            
            present(alert, animated: true, completion: nil)
        }
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
