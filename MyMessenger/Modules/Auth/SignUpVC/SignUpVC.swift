//
//  SignUpVC.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 2/16/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import UIKit
import SwiftyRSA

class SignUpVC: UIViewController {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    fileprivate let networking = NetworkingService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
}

//MARK: - Actions
extension SignUpVC {
    @IBAction func signUpAction() {
        let keyPair = try? SwiftyRSA.generateRSAKeyPair(sizeInBits: 2048)
        let privateKey = keyPair?.privateKey
        let publicKey = keyPair?.publicKey
        
        let clearPassword = try! ClearMessage(string: passwordTextField.text!, using: .utf8)
        let encrPassword = try! clearPassword.encrypted(with: serverPublicKey, padding: .PKCS1)
        guard let pubKey = publicKey, let privKey = privateKey else { return }
        let pubKeyStr = try! pubKey.base64String()
        
        let registrationModel = RegistrationModel(key: pubKeyStr, name: nameTextField.text!, password: encrPassword.base64String, email: emailTextField.text!)
        
        networking.performRequest(to: EndpointCollection.signup, with: registrationModel) { [weak self](result: Result<AuthResponse>) in
            switch result {
            case .success(let response):
                print(response)
                CurrentUserModel.shared.model = response.user
                DispatchQueue.main.async {
                    var user = UserModel(login: (self?.emailTextField.text)!, password: encrPassword.base64String, token: response.token)
                    user.privateKey = try! privKey.pemString()
                    user.publicKey = try! pubKey.pemString()
                    User.save(model: user)
                    self?.navigate(.chatList)
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    @IBAction func loginAction() {
        navigate(.auth(.logIn))
    }
}
