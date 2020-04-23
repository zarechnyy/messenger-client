//
//  AppDelegate.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 2/9/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Router.default.setupAppNavigation(appNavigation: MyAppNavigation())
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIStoryboard(name: "SplashScreen", bundle: nil).instantiateInitialViewController()
        window?.makeKeyAndVisible()
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        let msgModel = SocketResponseCommandModel(type: 6, model: .create(SocketMessageModel(message: "")))
        mainSocketService.send(msgModel)
    }

}

