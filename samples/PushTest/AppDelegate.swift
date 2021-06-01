//
//  AppDelegate.swift
//  PushTest
//
//  Created by Anthony Putignano on 5/3/21.
//

import UIKit
import UserNotifications
import Snapyr

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let configuration = SnapyrConfiguration(writeKey: "FBa8x47JC3PzO1YOE4ojqxcGGCPyPesD")
        configuration.trackApplicationLifecycleEvents = true // Enable this to record certain application events automatically!
        configuration.recordScreenViews = true // Enable this to record screen views automatically!
        configuration.actionHandler = {
            action in
            print("ACTION ", action)
            let zone = action["zone"]!
            let userId = action["userId"]!
            NSLog("Action Received zone=\(zone) userId=\(userId)")
        }
        Snapyr.debug(true)
        Snapyr.setup(with: configuration)
        Snapyr.shared().identify("wikram")
        
        var settings: [AnyHashable: Any]
        let url = URL(
            string: "https://dev-api.snapyr.com/sdk/RSLG3AdcWnHBvqxdGvZJ6FtkNAmudjtX"
        )!
        do {
            let data = try Data(contentsOf: url)
            settings = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any] ?? [:]
            // Configure Categories & Actions
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            }

            let pushAdaptor = PushAdaptor()
            //pushAdaptor.configureNotifications(fromSettings:settings, with:notificationCenter)
            pushAdaptor.configureCategories(settings, with:notificationCenter)
            return true
        } catch {
            print("JsonError: ", error) 
        }
        return false
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    
}

