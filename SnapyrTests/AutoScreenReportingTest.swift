//
// Created by David Whetstone on 2018-11-04.
// Copyright (c) 2018 Segment. All rights reserved.
//

import Foundation
@testable import Snapyr
import XCTest

#if os(iOS)
class AutoScreenReportingTests: XCTestCase {
    
    var window: UIWindow!
    var rootVC: UIViewController!
    
    override func setUp() {
        super.setUp()
        window = UIWindow()
        rootVC = UIViewController()
        window.addSubview(rootVC.view)
    }
    
    func testTopViewControllerReturnController() {
        let actualVC = UIViewController.snapyr_topViewController(rootVC)
        XCTAssertEqual(actualVC, rootVC)
    }
    
    func testTopViewControllerReturnsPresentedController() {
        var expectedVC: UIViewController!
        expectedVC = UIViewController()
        rootVC.present(expectedVC, animated: false)
        let actualVC = UIViewController.snapyr_topViewController(rootVC)
        XCTAssertEqual(actualVC, expectedVC)
        
    }
    
    func testTopViewControllerReturnsPushedViewController() {
        var expectedVC: UIViewController!
        expectedVC = UIViewController()
        let nc = UINavigationController()
        rootVC.present(nc, animated: false)
        nc.pushViewController(expectedVC, animated: false)
        let actualVC = UIViewController.snapyr_topViewController(rootVC)
        XCTAssertEqual(actualVC, expectedVC)
    }
    
    func testTopViewControllerTeturnsCurrentSelectedController() {
        var expectedVC: UIViewController!
        expectedVC = UIViewController()
        let tabBarController = UITabBarController()
        rootVC.present(tabBarController, animated: false)
        tabBarController.viewControllers = [UIViewController(), expectedVC, UIViewController()]
        tabBarController.selectedIndex = 1
        let actualVC = UIViewController.snapyr_topViewController(rootVC)
        XCTAssertEqual(actualVC, expectedVC)
    }
    
    func testTopViewControllerReturnsCurrentSelectedViewController() {
        class CustomContainerViewController: UIViewController, SnapyrScreenReporting {
            var selectedIndex: Int = 0
            var snapyr_mainViewController: UIViewController? {
                return children[selectedIndex]
            }
        }
        
        var expectedVC: UIViewController!
        expectedVC = UIViewController()
        let containerVC = CustomContainerViewController()
        rootVC.present(containerVC, animated: false)
        [UIViewController(), expectedVC, UIViewController()].forEach { child in
            containerVC.addChild(child)
        }
        containerVC.selectedIndex = 1
        let actualVC = UIViewController.snapyr_topViewController(rootVC)
        XCTAssertEqual(actualVC, expectedVC)
    }
    
    func testTopViewControllerReturnsChildViewController() {
        var expectedVC: UIViewController!
        expectedVC = UIViewController()
        let containerVC = UIViewController()
        rootVC.present(containerVC, animated: false)
        [expectedVC, UIViewController(), UIViewController()].forEach { child in
            containerVC.addChild(child)
        }
        let actualVC = UIViewController.snapyr_topViewController(rootVC)
        XCTAssertEqual(actualVC, expectedVC)
    }
}
#endif
