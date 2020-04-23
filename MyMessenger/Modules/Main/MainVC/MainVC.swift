//
//  MainVC.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 3/16/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import UIKit
import SwiftyRSA
import SwCrypt

var mainSocketService: SocketService = SocketService()

class MainVC: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    fileprivate var networking = NetworkingService()
    fileprivate var items = [ServerUserModel]()
    fileprivate var selectedUser: ServerUserModel!
    
        
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        configureSocketConnection()
    }
    
    fileprivate func getAllUsers() {
        networking.performRequest(to: EndpointCollection.getAllUsers) { [weak self] (result: Result<UserModelResponse>) in
            switch result {
            case .success(let response):
                self?.items = response.users
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    fileprivate func startChat(_ userID: Int) {
        let startChatModel = StartChatModel(id: userID)
        
        networking.performRequest(to: EndpointCollection.startChat, with: startChatModel) { [weak self] (result: Result<StartChatResponse>) in
            switch result {
            case .success(let response):
                guard let self = self else { return }
                do {
                    let clear = try! ClearMessage(string: response.key, using: .utf8)
                    let signature = try Signature(base64Encoded: response.signature)
                    let isSuccessful = try clear.verify(with: serverPublicKey, signature: signature, digestType: .sha256)
                    
                    if isSuccessful {
                        DispatchQueue.main.async {
                            self.navigate(.chatRoom(response.key, self.selectedUser))
                        }
                    }
                } catch {
                    print(error)
                }
            case .failure(let error):
                print(error)
            }
        }
    }
}

//MARK: - Configure
extension MainVC {
    fileprivate func configure() {
        tableView.register(ChatListCell.nib(), forCellReuseIdentifier: ChatListCell.reuseIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        getAllUsers()
    }
    
    fileprivate func configureSocketConnection() {
        var request = URLRequest(url: URL(string: "ws://localhost:8181/online")!)
        request.setValue("Bearer \(User.current?.token ?? "")", forHTTPHeaderField: "Authorization")
        mainSocketService.connect(with: request, delegate: self)
    }
}

extension MainVC: SocketServiceDelegate {
    func didConnect() { }
    
    func didReceive(_ error: Error?) { }
    
    func didReceive(_ model: SocketResponseCommandModel) {
        switch model.model {
        case .users(let response):
            
            for (index, _) in items.enumerated() {
                items[index].setOffline()
            }
            
            for (index, _) in items.enumerated() {
                if response.users.contains(where: {$0.id == items[index].id}) {
                    items[index].setOnline()
                }
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        default: break
        }
    }
    
    func didDisconnect() { }
}

//MARK: - UITableViewDataSource
extension MainVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatListCell.reuseIdentifier, for: indexPath) as! ChatListCell
        cell.titleLabel.text = items[indexPath.row].username
        if items[indexPath.row].isOnline {
            cell.statusView.backgroundColor = .green
        } else {
            cell.statusView.backgroundColor = .red
        }
        
        return cell
    }
}

//MARK: - UITableViewDelegate
extension MainVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedUser = items[indexPath.row]
        startChat(selectedUser.id)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
}
