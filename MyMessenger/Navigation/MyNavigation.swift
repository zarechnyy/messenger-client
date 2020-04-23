//
//  MyNavigation.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 2/16/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import UIKit

// MARK: - Navigation enum

enum MyNavigation: Navigation {
    case launchScreen
    case auth(AuthMode)
    case chatList
    case chatRoom(String, ServerUserModel)

    enum AuthMode {
        case signUp
        case logIn
    }
}


struct MyAppNavigation: AppNavigation {
    private let authNC = { () -> UINavigationController in
        let nc = UINavigationController()
        nc.isNavigationBarHidden = true
        return nc
    }()

    private let mainNC = { () -> UINavigationController in
        let nc = UINavigationController()
        nc.isNavigationBarHidden = true
        return nc
    }()
    
    func viewcontrollerForNavigation(navigation: Navigation) -> UIViewController {
        guard let navigation = navigation as? MyNavigation else {
            preconditionFailure("Invalid navigation enum type")
        }
        switch navigation {
        case .launchScreen:
            return UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()!
        case .auth(let authMode):
            let storyboard = UIStoryboard(name: "Auth", bundle: nil)
            switch authMode {
            case .logIn:
                return storyboard.instantiateViewController(withIdentifier: "logInVC")
            case .signUp:
                return storyboard.instantiateViewController(withIdentifier: "signUpVC")
            }
        case .chatList:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            return storyboard.instantiateInitialViewController()!
        case .chatRoom(let key, let selectedUser):
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "ChatViewController") as! ChatVC
            vc.messageProcessService = MessageProcessService(userPubKey: key)
            vc.user = selectedUser
            return vc
        }
    }
    
    func navigate(_ navigation: Navigation, from: UIViewController, to: UIViewController) {
        guard let navigation = navigation as? MyNavigation else {
            preconditionFailure("Invalid navigation enum type")
        }
        switch navigation {
            case .launchScreen:
                setRoot(viewController: to)
            case .auth(let authMode):
                setRoot(viewController: authNC)
                switch authMode {
                case .signUp:
                    if let previous = authNC.viewControllers.first(where: { $0 is SignUpVC }) {
                        authNC.popToViewController(previous, animated: true)
                    } else {
                        authNC.pushViewController(to, animated: true)
                    }
                case .logIn:
                    if let previous = authNC.viewControllers.first(where: { $0 is LoginVC }) {
                        authNC.popToViewController(previous, animated: true)
                    } else {
                        authNC.pushViewController(to, animated: true)
                    }
                }
        case .chatList:
            setRoot(viewController: mainNC)
            mainNC.pushViewController(to, animated: true)
        case .chatRoom:
            mainNC.pushViewController(to, animated: true)
        }
    }
    
    private func setRoot(viewController: UIViewController) {
        guard let window = (UIApplication.shared.delegate as! AppDelegate).window else {
            preconditionFailure("Can't get window")
        }
        guard window.rootViewController != viewController else {
            return
        }
    
        window.rootViewController = viewController
        
        let options: UIView.AnimationOptions = .transitionCrossDissolve
        let duration: TimeInterval = 0.3
        
        UIView.transition(with: window, duration: duration, options: options, animations: {}, completion: nil)
    }

}

// MARK: - VC navigation by enum

extension UIViewController {
    func navigate(_ navigation: MyNavigation) {
        navigate(navigation as Navigation)
    }
}
