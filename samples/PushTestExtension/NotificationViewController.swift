//
//  NotificationViewController.swift
//  PushTestExtension
//
//  Created by Brian O'Neill on 5/24/21.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import Snapyr


class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad")
    }
    
    func didReceive(_ notification: UNNotification) {
        let notificationCenter = UNUserNotificationCenter.current()
        self.label?.text = "foo"
        print("didReceive")
        let imageKey = notification.request.content.userInfo["imageUrl"] as! String
        //if let urlString = notification.request.content.userInfo["attachment-url"] as! String? {
        if let imageURL = URL(string: imageKey) {
            if let data = NSData(contentsOf: imageURL) {
                self.imageView.image = UIImage(data: data as Data)
            }
        }
        
        
//        // Define the custom actions.
//        let acceptAction = UNNotificationAction(identifier: "ACCEPT_ACTION",
//                                                title: "Three",
//                                                options: UNNotificationActionOptions(rawValue: 0))
//        let declineAction = UNNotificationAction(identifier: "DECLINE_ACTION",
//                                                 title: "Four",
//                                                 options: UNNotificationActionOptions(rawValue: 0))
//        // Define the notification type
//        let meetingInviteCategory =
//            UNNotificationCategory(identifier: "buttons_galore",
//                                   actions: [acceptAction, declineAction],
//                                   intentIdentifiers: [],
//                                   hiddenPreviewsBodyPlaceholder: "",
//                                   options: .customDismissAction)
//        notificationCenter.setNotificationCategories([meetingInviteCategory])

        let pushAdaptor = PushAdaptor()
        let categories = pushAdaptor.configureCategories(notification.request.content.userInfo, with: notificationCenter)
        print("Configure [\(categories.count)] categories... {")
        for category in categories {
            print("Category = [\(category.identifier)] {")
            for action in category.actions {
                print(   ".action = ([\(action.identifier)], [\(action.title)])")
            }
            print("}")
        }
    }
    
}
