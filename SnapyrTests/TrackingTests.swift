//
//  TrackingTests.swift
//  Analytics
//
//  Created by Tony Xiao on 9/16/16.
//  Copyright © 2016 Segment. All rights reserved.
//


import Snapyr
import XCTest

class TrackingTests: XCTestCase {
    enum TestError: String, Error {
        case testError
    }
    var passthrough: PassthroughMiddleware!
    var sdk: Snapyr!
    
    override func setUp() {
        super.setUp()
        passthrough = PassthroughMiddleware()
        sdk = getUnitTestSDK(application:nil, sourceMiddleware: [passthrough], destinationMiddleware: [])
        Snapyr.debug(true)
    }
    
    override func tearDown() {
        super.tearDown()
        sdk.reset()
    }
    /*
    func testOpenUrl() {
        sdk.open(.init(string: "https://blah.com/")!, options: [:])
        
        let payload = passthrough.lastContext?.payload as? TrackPayload
        XCTAssertEqual(passthrough.lastContext?.eventType, .track)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.event, "Deep Link Opened")
        XCTAssertEqual(payload?.properties?["url"] as? String, "https://blah.com/")
    }*/
    
    func testContinueUserActivity() {
        let userActivity = NSUserActivity(activityType: "test")
        sdk.continue(userActivity)
        
        let payload = passthrough.lastContext?.payload as? ContinueUserActivityPayload
        XCTAssertEqual(passthrough.lastContext?.eventType, .continueUserActivity)
        XCTAssertNotNil(payload)
    }
    
    func testHandleActionWithIdentifier() {
        let actionIdentifier = "snapyrsdk"
        sdk.handleAction(withIdentifier: actionIdentifier, forRemoteNotification: [:])
        let payload = passthrough.lastContext?.payload as? RemoteNotificationPayload
        XCTAssertEqual(passthrough.lastContext?.eventType, .handleActionWithForRemoteNotification)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.actionIdentifier, actionIdentifier)
    }
    
    func testRegisteredForRemoteNotificationsWithDeviceToken() {
        let deviceToken = UUID().uuidString.data(using: .ascii)!
        sdk.registeredForRemoteNotifications(withDeviceToken: deviceToken)
        let payload = passthrough.lastContext?.payload as? RemoteNotificationPayload
        XCTAssertNotNil(payload)
        XCTAssertEqual(passthrough.lastContext?.eventType, .registeredForRemoteNotifications)
        XCTAssertEqual(payload?.deviceToken, deviceToken)
    }
    
    func testFailedToRegisterForRemoteNotifications() {
        
        sdk.failedToRegisterForRemoteNotificationsWithError(TestError.testError)
        
        let payload = passthrough.lastContext?.payload as? RemoteNotificationPayload
        XCTAssertEqual(passthrough.lastContext?.eventType, .failedToRegisterForRemoteNotifications)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.error as? TestError, TestError.testError)
    }
    
    func testPushNotificationReceived(){
        let testPayload = getTestUserInfo()
        sdk.pushNotificationReceived(testPayload)
        
        let testSnapyrPayload = testPayload["snapyr"] as? NSDictionary
        let payload = passthrough.lastContext?.payload as? TrackPayload
        XCTAssertEqual(passthrough.lastContext?.eventType, .track)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.event, "snapyr.observation.event.Impression")
        XCTAssertEqual(payload?.properties?["actionToken"] as? String, testSnapyrPayload?["actionToken"] as? String)
        XCTAssertEqual(payload?.properties?["deepLinkUrl"] as? String, testSnapyrPayload?["deepLinkUrl"] as? String)
        print(payload?.properties)
        print(testPayload)
    }
    
    func testPushNotificationTapped(){
        let testPayload = getTestUserInfo()
        sdk.pushNotificationTapped(testPayload, actionId: "snapyrsdk")
        
        let payload = passthrough.lastContext?.payload as? TrackPayload
        XCTAssertEqual(passthrough.lastContext?.eventType, .track)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.event, "snapyr.observation.event.Behavior")
        XCTAssertEqual(payload?.properties?["actionToken"] as? String, testPayload["actionToken"] as? String)
        XCTAssertEqual(payload?.properties?["deepLinkUrl"] as? String, testPayload["deepLinkUrl"] as? String)
        XCTAssertEqual(payload?.properties?["actionId"] as? String, "snapyrsdk")
    }
    
    func testReceivedRemoteNotification() {
        let testPayload = getTestUserInfo()
        sdk.receivedRemoteNotification(testPayload)
        
        let payload = passthrough.lastContext?.payload as? RemoteNotificationPayload
        XCTAssertEqual(passthrough.lastContext?.eventType, .receivedRemoteNotification)
        XCTAssertNotNil(payload)
        let snapyrInfo = payload?.userInfo?["snapyr"] as? [String: Any]
        let expectedSnapyrInfo = testPayload["snapyr"] as? [String: Any]
        XCTAssertNotNil(snapyrInfo)
        XCTAssertEqual(snapyrInfo?["deepLinkUrl"] as? String, expectedSnapyrInfo?["deepLinkUrl"] as? String)
        XCTAssertEqual(snapyrInfo?["imageUrl"] as? String, expectedSnapyrInfo?["imageUrl"] as? String)
        XCTAssertEqual(snapyrInfo?["actionToken"] as? String, expectedSnapyrInfo?["actionToken"] as? String)
        XCTAssertEqual((snapyrInfo?["pushTemplate"] as? [String: Any])?["id"] as? String, (expectedSnapyrInfo?["pushTemplate"] as? [String: Any])?["id"] as? String)
        XCTAssertEqual((snapyrInfo?["pushTemplate"] as? [String: Any])?["modified"] as? String, (expectedSnapyrInfo?["pushTemplate"] as? [String: Any])?["modified"] as? String)
    }
    
    
    func testHandlesIdentify() {
        sdk.identify("testUserId1", traits: [
            "firstName": "Peter"
        ])
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.identify)
        let identify = passthrough.lastContext?.payload as? IdentifyPayload
        XCTAssertEqual(identify?.userId, "testUserId1")
        XCTAssertNotNil(identify?.anonymousId)
        XCTAssertEqual(identify?.traits?["firstName"] as? String, "Peter")
    }
    
    func testHandlesIdentifyAndUserIdPass() {
        sdk.identify("testUserId1", traits: [
            "firstName": "Peter"
        ])
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.identify)
        let identify = passthrough.lastContext?.payload as? IdentifyPayload
        XCTAssertEqual(identify?.userId, "testUserId1")
        XCTAssertNotNil(identify?.anonymousId)
        XCTAssertEqual(identify?.traits?["firstName"] as? String, "Peter")
        XCTAssertEqual(identify?.traits?["userId"] as? String, "testUserId1")
        
        sdk.identify("testUserId1")
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.identify)
        let identify2 = passthrough.lastContext?.payload as? IdentifyPayload
        XCTAssertEqual(identify2?.userId, "testUserId1")
        XCTAssertEqual(identify2?.traits?["userId"] as? String, "testUserId1")
    }
    
    func testHandlesIdentifyWithCustomAnonymousId() {
        sdk.identify("testUserId1", traits: [
            "firstName": "Peter"
            ], options: [
                "anonymousId": "a_custom_anonymous_id"
        ])
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.identify)
        let identify = passthrough.lastContext?.payload as? IdentifyPayload
        XCTAssertEqual(identify?.userId, "testUserId1")
        XCTAssertEqual(identify?.anonymousId, "a_custom_anonymous_id")
        XCTAssertEqual(identify?.traits?["firstName"] as? String, "Peter")
    }
    
    func testHandlesTrack() {
        sdk.track("User Signup", properties: [
            "method": "SSO"
            ], options: [
                "context": [
                    "device": [
                        "token": "1234"
                    ]
                ]
        ])
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.track)
        let payload = passthrough.lastContext?.payload as? TrackPayload
        XCTAssertEqual(payload?.event, "User Signup")
        XCTAssertEqual(payload?.properties?["method"] as? String, "SSO")
    }
    
    func testHandlesAlias() {
        sdk.alias("persistentUserId")
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.alias)
        let payload = passthrough.lastContext?.payload as? AliasPayload
        XCTAssertEqual(payload?.theNewId, "persistentUserId")
    }
    
    func testHandlesScreen() {
        sdk.screen("Home", category:"test", properties: [
            "referrer": "Google"
        ])
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.screen)
        let screen = passthrough.lastContext?.payload as? ScreenPayload
        XCTAssertEqual(screen?.name, "Home")
        XCTAssertEqual(screen?.category, "test")
        XCTAssertEqual(screen?.properties?["referrer"] as? String, "Google")
    }
    
    func testHandlesGroup() {
        sdk.group("acme-company", traits: [
            "employees": 2333
        ])
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.group)
        let payload = passthrough.lastContext?.payload as? GroupPayload
        XCTAssertEqual(payload?.groupId, "acme-company")
        XCTAssertEqual(payload?.traits?["employees"] as? Int, 2333)
    }
    
    func testHandlesNullValues() {
        sdk.track("null test", properties: [
            "nullTest": NSNull()
        ])
        let payload = passthrough.lastContext?.payload as? TrackPayload
        let isNull = (payload?.properties?["nullTest"] is NSNull)
        XCTAssert(isNull)
    }
}
