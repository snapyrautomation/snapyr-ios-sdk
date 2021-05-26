//
//  NotificationViewController.swift
//  PushTestExtension
//
//  Created by Brian O'Neill on 5/24/21.
//

import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad")
    }
    
    func didReceive(_ notification: UNNotification) {
        self.label?.text = "foo"
        print("didReceive")
        //if let urlString = notification.request.content.userInfo["attachment-url"] as! String? {
        if let imageURL = URL(string: "https://skookle.com/screen_shot.png") {
            if let data = NSData(contentsOf: imageURL) {
                self.imageView.image = UIImage(data: data as Data)
            }
        }
    }
}

