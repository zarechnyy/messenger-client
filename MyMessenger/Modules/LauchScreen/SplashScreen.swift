//
//  LauchScreen.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 2/16/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import UIKit
import SwiftyRSA

class SplashScreen: UIViewController {
    
    fileprivate let networking = NetworkingService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        route()
    }
}


extension SplashScreen {
    fileprivate func route() {
        if let user = User.current, let _ = user.publicKey, let _ = user.privateKey {
            let loginModel = LoginModel(password: user.password, email: user.login)
            networking.performRequest(to: EndpointCollection.login, with: loginModel) { [weak self] (result: Result<AuthResponse>) in
                switch result {
                case .success(let response):
                    User.update(token: response.token)
                    CurrentUserModel.shared.model = response.user
                    DispatchQueue.main.async {
                        self?.navigate(.chatList)
                    }
                case .failure(let error):
                    print(error)
                    DispatchQueue.main.async {
                        self?.navigate(.auth(.logIn))
                    }
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.navigate(.auth(.logIn))
            }
        }
    }
}
