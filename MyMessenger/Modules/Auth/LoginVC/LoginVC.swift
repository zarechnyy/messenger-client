//
//  ViewController.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 2/9/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import UIKit
import SwiftyRSA

class LoginVC: UIViewController {
    
    @IBOutlet weak var loginTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    fileprivate let networking = NetworkingService()

    override func viewDidLoad() {
        super.viewDidLoad()
    }
        
    func searchUser() {
        let url = URL(string:"http://localhost:8181/users/Ke")
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"
        request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1ODIxNDA5NDh9.2Jiqq9zlWclp2ov-es97DSZ1NOmocHo85k-noXg6fD8", forHTTPHeaderField: "Authorization")
       
        let dataTask = URLSession.shared.dataTask(with: request) { (data, res, err) in
            print(String(decoding: data!, as: UTF8.self))
        }
        
        dataTask.resume()
    }
    
    fileprivate func shake(_ textField: UITextField) {
        let midX = textField.center.x
        let midY = textField.center.y
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = 0.06
        animation.repeatCount = 3
        animation.autoreverses = true
        animation.fromValue = CGPoint(x: midX - 6, y: midY)
        animation.toValue = CGPoint(x: midX + 6, y: midY)
        textField.layer.add(animation, forKey: "position")
    }

}

//MARK: - Actions
extension LoginVC {
    
    @IBAction func loginUp() {
        guard !(loginTextField.text ?? "").isEmpty else {
            shake(loginTextField)
            return
        }
        guard !(passwordTextField.text ?? "").isEmpty else {
            shake(passwordTextField)
            return
        }
        let clear = try! ClearMessage(string: passwordTextField.text!, using: .utf8)
        let encr = try! clear.encrypted(with: serverPublicKey, padding: .PKCS1)
        
        let loginModel = LoginModel(password: encr.base64String, email: loginTextField.text!)
        networking.performRequest(to: EndpointCollection.login, with: loginModel) { [weak self] (result: Result<AuthResponse>) in
            switch result {
            case .success(let response):
                CurrentUserModel.shared.model = response.user
                User.update(token: response.token)
                DispatchQueue.main.async {
                    self?.navigate(.chatList)
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    @IBAction func signUpAction() {
        navigate(.auth(.signUp))
    }
}
