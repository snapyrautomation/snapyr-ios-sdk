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
    }
    
    func didReceive(_ notification: UNNotification) {
        self.label?.text = "foo"
        let imageKey = notification.request.content.userInfo["imageUrl"] as! String
        if let imageURL = URL(string: imageKey) {
            if let data = NSData(contentsOf: imageURL) {
                self.imageView.image = UIImage(data: data as Data)
            }
        }
        self.view.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        self.view.translatesAutoresizingMaskIntoConstraints = false;
        let pushAdaptor = PushAdaptor()
        pushAdaptor.configureCategories(notification.request.content.userInfo, with: UNUserNotificationCenter.current())
    }
}
