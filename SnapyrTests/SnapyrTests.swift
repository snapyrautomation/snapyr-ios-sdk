//
//  SDKTests.swift
//  Analytics
//
//  Created by Tony Xiao on 9/16/16.
//  Copyright © 2016 Segment. All rights reserved.
//


@testable import Snapyr
import XCTest

class SnapyrTests: XCTestCase {
    
    let cachedSettings = [
        "integrations": [
            "Snapyr": [
                "apiKey": "QUI5ydwIGeFFTa1IvCBUhxL9PyW5B0jE",
            ]
        ],
        "plan": ["track": [:]],
    ] as NSDictionary
    let cachedSettingsWithHost = [
        "integrations": [
            "Snapyr": [
                "apiKey": "QUI5ydwIGeFFTa1IvCBUhxL9PyW5B0jE",
                "apiHost": "dev-engine.snapyrdev.net/v1"
            ]
        ],
        "plan": ["track": [:]],
    ] as NSDictionary
    
    var sdk: Snapyr!
    var testMiddleware: TestMiddleware!
    var testApplication: TestApplication!
    
    override func setUp() {
        super.setUp()
        testMiddleware = TestMiddleware()
        testApplication = TestApplication()
        UserDefaults.standard.set("test SEGQueue should be removed", forKey: "snapyrQueue")
        // pump the run loop so we can be sure the value was written.
        RunLoop.current.run(until: Date.distantPast)
        XCTAssertNotNil(UserDefaults.standard.string(forKey: "snapyrQueue"))
        sdk = getUnitTestSDK(application: testApplication,
                             sourceMiddleware: [testMiddleware], destinationMiddleware: [])
        sdk.test_integrationsManager()?.test_setCachedSettings(settings: cachedSettings)
    }
    
    override func tearDown() {
        super.tearDown()
        sdk.reset()
    }
    
//    func testInitializedCorrectly() {
//
//        UserDefaults.standard.removeObject(forKey: "snapyr_apihost")
//        XCTAssertEqual(config.flushAt, 20)
//        XCTAssertEqual(config.flushInterval, 30)
//        XCTAssertEqual(config.maxQueueSize, 1000)
//        XCTAssertEqual(config.writeKey, "QUI5ydwIGeFFTa1IvCBUhxL9PyW5B0jE")
//        XCTAssertEqual(config.apiHost?.absoluteString, "https://\(TestVariables.apiHost)/v1")
//        XCTAssertEqual(config.shouldUseLocationServices, false)
//        XCTAssertEqual(config.enableAdvertisingTracking, true)
//        XCTAssertEqual(config.shouldUseBluetooth,  false)
//        XCTAssertNil(config.httpSessionDelegate)
//        XCTAssertNotNil(sdk.getAnonymousId())
//    }
    
    func testConfigAPIHost() {
        // gotta remove the key first
        getGroupUserDefaults().removeObject(forKey: "snapyr_apihost")
        let dummyHost = URL(string: "https://blah.com/")
        let config3 = SnapyrConfiguration(writeKey: "TESTKEY", defaultAPIHost: dummyHost)
        
        let currentHost = config3.apiHost?.absoluteString
        let storedHost = getGroupUserDefaults().string(forKey: "snapyr_apihost")
        
        XCTAssertEqual(config3.apiHost, dummyHost)
        XCTAssertEqual(currentHost, storedHost)
    }
    
    func testCachedSettingsAPIHost() {
        getGroupUserDefaults().removeObject(forKey: "snapyr_apihost")
        var initialized = false
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: SnapyrSDKIntegrationDidStart), object: nil, queue: nil) { (notification) in
            let key = notification.object as? String
            if (key == "Snapyr") {
                initialized = true
            }
        }
        let config2 = SnapyrConfiguration(writeKey: "TESTKEY")
        let snapyr2 = Snapyr(configuration: config2)
        snapyr2.test_integrationsManager()?.test_setCachedSettings(settings: cachedSettingsWithHost)
        
        while (!initialized) { // wait for integrations to get setup
            sleep(1)
        }
        
        // see if the value in use is the correct endpoint.
        XCTAssertEqual(config2.apiHost?.absoluteString, "https://\(TestVariables.apiHost)/v1")
        snapyr2.test_integrationsManager()?.test_setCachedSettings(settings: cachedSettings)
    }
    
    //    func testWebhookIntegrationInitializedCorrectly() {
    //        let webhookIntegration = WebhookIntegrationFactory.init(name: "dest1", webhookUrl: "blah")
    //        let webhookIntegrationKey = webhookIntegration.key()
    //        var initialized = false
    //        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: SnapyrSDKIntegrationDidStart), object: nil, queue: nil) { (notification) in
    //            let key = notification.object as? String
    //            if (key == webhookIntegrationKey) {
    //                initialized = true
    //            }
    //        }
    //        let config2 = SnapyrConfiguration(writeKey: "TESTKEY")
    //        config2.use(webhookIntegration)
    //        let snapyr2 = Snapyr(configuration: config2)
    //        let factoryList = (config2.value(forKey: "factories") as? NSMutableArray)
    //        XCTAssertEqual(factoryList?.count, 1)
    //
    //        while (!initialized) { // wait for WebhookIntegration to get setup
    //            sleep(1)
    //        }
    //        XCTAssertNotNil(snapyr2.test_integrationsManager()?.test_integrations()?[webhookIntegrationKey])
    //    }
    
    func testClearsSEGQueueFromUserDefaults() {
        expectUntil(2.0, expression: getGroupUserDefaults().string(forKey: "snapyrQueue") == nil)
    }
    
    /* TODO: Fix me when the Context object isn't so wild.
     func testCollectsIDFA() {
     testMiddleware.swallowEvent = true
     snapyr.configuration.enableAdvertisingTracking = true
     snapyr.configuration.adSupportBlock = { () -> String in
     return "1234AdsNoMore!"
     }
     
     snapyr.track("test");
     
     let event = testMiddleware.lastContext?.payload as? TrackPayload
     XCTAssertEqual(event?.properties?["url"] as? String, "myapp://auth?token=((redacted/my-auth))&other=stuff")
     }*/
    
    func testPersistsAnonymousId() {
        let config = SnapyrConfiguration(writeKey: "RSLG3AdcWnHBvqxdGvZJ6FtkNAmudjtX")
        let sdk2 = Snapyr(configuration: config)
        XCTAssertEqual(sdk.getAnonymousId(), sdk2.getAnonymousId())
    }
    
    func testPersistsTraits() {
        let config = SnapyrConfiguration(writeKey: "RSLG3AdcWnHBvqxdGvZJ6FtkNAmudjtX")
        sdk.identify("testUserId1", traits: ["trait1": "someTrait"])
        let sdk2 = Snapyr(configuration: config)
        sdk2.test_integrationsManager()?.test_setCachedSettings(settings: cachedSettings)
        
        XCTAssertEqual(sdk.test_integrationsManager()?.test_snapyrIntegration()?.test_userId(), "testUserId1")
        XCTAssertEqual(sdk2.test_integrationsManager()?.test_snapyrIntegration()?.test_userId(), "testUserId1")
        
        var traits = sdk.test_integrationsManager()?.test_snapyrIntegration()?.test_traits()
        var storedTraits = sdk2.test_integrationsManager()?.test_snapyrIntegration()?.test_traits()
        
        if let trait1 = traits?["trait1"] as? String {
            XCTAssertEqual(trait1, "someTrait")
        } else {
            XCTAssert(false, "Traits are nil!")
        }
        
        if let storedTrait1 = storedTraits?["trait1"] as? String {
            XCTAssertEqual(storedTrait1, "someTrait")
        } else {
            XCTAssert(false, "Traits were not stored!")
        }
        
        sdk.identify("testUserId1", traits: ["trait2": "someOtherTrait"])
        
        traits = sdk.test_integrationsManager()?.test_snapyrIntegration()?.test_traits()
        storedTraits = sdk2.test_integrationsManager()?.test_snapyrIntegration()?.test_traits()
        
        if let trait1 = traits?["trait2"] as? String {
            XCTAssertEqual(trait1, "someOtherTrait")
        } else {
            XCTAssert(false, "Traits are nil!")
        }
        
        if let storedTrait1 = storedTraits?["trait2"] as? String {
            XCTAssertEqual(storedTrait1, "someOtherTrait")
        } else {
            XCTAssert(false, "Traits were not stored!")
        }
    }
    
    func testClearsUserData() {
        sdk.identify("testUserId1", traits: [ "Test trait key" : "Test trait value"])
        sdk.reset()
        
        expectUntil(2.0, expression: self.sdk.test_integrationsManager()?.test_snapyrIntegration()?.test_userId() == nil)
        
        expectUntil(2.0, expression: self.sdk.test_integrationsManager()?.test_snapyrIntegration()?.test_traits()?.count == 0)
    }
    
    #if os(iOS)
    func testFiresApplicationOpenedForAppLaunchingEvent() {
        testMiddleware.swallowEvent = true
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: testApplication, userInfo: [
            UIApplication.LaunchOptionsKey.sourceApplication: "testApp",
            UIApplication.LaunchOptionsKey.url: "test://test",
        ])
        let event = testMiddleware.lastContext?.payload as? TrackPayload
        XCTAssertEqual(event?.event, "Application Opened")
        XCTAssertEqual(event?.properties?["from_background"] as? Bool, false)
        XCTAssertEqual(event?.properties?["referring_application"] as? String, "testApp")
        XCTAssertEqual(event?.properties?["url"] as? String, "test://test")
    }
    #else
    #endif
    
    func testFiresApplicationEnterForeground() {
        testMiddleware.swallowEvent = true
        #if os(macOS)
        NotificationCenter.default.post(name: NSApplication.willBecomeActiveNotification, object: testApplication)
        #else
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: testApplication)
        #endif
        let event = testMiddleware.lastContext?.payload as? TrackPayload
        XCTAssertEqual(event?.event, "Application Opened")
        XCTAssertEqual(event?.properties?["from_background"] as? Bool, true)
    }
    
    func testFiresApplicationDuringEnterBackground() {
        testMiddleware.swallowEvent = true
        #if os(macOS)
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: testApplication)
        #else
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: testApplication)
        #endif
        let event = testMiddleware.lastContext?.payload as? TrackPayload
        XCTAssertEqual(event?.event, "Application Backgrounded")
    }
    
    func testFlushesWhenApplicationBackgroundIsFired() {
        sdk.track("test")
        #if os(macOS)
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: testApplication)
        #else
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: testApplication)
        #endif
        
        expectUntil(2.0, expression: self.testApplication.backgroundTasks.count == 1)
        expectUntil(2.0, expression: self.testApplication.backgroundTasks[0].isEnded == false)
    }
    
    func testRespectsMaxQueueSize() {
        let config = SnapyrConfiguration(writeKey: "RSLG3AdcWnHBvqxdGvZJ6FtkNAmudjtX")
        config.snapyrEnvironment = SnapyrEnvironment.dev
        let max = 72
        config.maxQueueSize = UInt(max)
        let sdk2 = Snapyr(configuration: config)
        for i in 1...max * 2 {
            sdk2.track("test #\(i)")
        }
        
        let integration = sdk2.test_integrationsManager()?.test_snapyrIntegration()
        XCTAssertNotNil(integration)
        let timeOut = Date() + 120
        while(integration?.test_queue()?.count != max && Date() < timeOut) {
            sdk2.track("test.maxQueue")
        }
        XCTAssertEqual(integration?.test_queue()?.count, max)
    }
    
    #if !os(macOS)
    func testProtocolConformanceShouldNotInterfere() {
        // In Xcode8/iOS10, UIApplication.h typedefs UIBackgroundTaskIdentifier as NSUInteger,
        // whereas Swift has UIBackgroundTaskIdentifier typealiaed to Int.
        // This is likely due to a custom Swift mapping for UIApplication which got out of sync.
        // If we extract the exact UIApplication method names in SnapyrApplicationProtocol,
        // it will cause a type mismatch between the return value from beginBackgroundTask
        // and the argument for endBackgroundTask.
        // This would impact all code in a project that imports the Snapyr framework.
        // Note that this doesn't appear to be an issue any longer in Xcode9b3.
        let task = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        UIApplication.shared.endBackgroundTask(task)
    }
    #endif
  
//    This test is bologna because it is reusing an existing snapyr instance and existing
//    integrations manager, whose state could be changed by another test.  When run in isolation,
//    this test passes, when run with other tests it does not.
//    func testFlushesUsingFlushTimer() {
//        let integration = snapyr.test_integrationsManager()?.test_snapyrIntegration()
//        snapyr.track("test")
//        expectUntil(2.0, expression: integration?.test_flushTimer() != nil)
//        XCTAssertNil(integration?.test_batchRequest())
//        integration?.test_flushTimer()?.fire()
//        expectUntil(2.0, expression: integration?.test_batchRequest() != nil)
//    }
    
    func testRespectsFlushIntervale() {
        let config = SnapyrConfiguration(writeKey: "RSLG3AdcWnHBvqxdGvZJ6FtkNAmudjtX")
        let timer = sdk
            .test_integrationsManager()?
            .test_snapyrIntegration()?
            .test_flushTimer()
        
        XCTAssertNotNil(timer)
        XCTAssertEqual(timer?.timeInterval, config.flushInterval)
    }
    
    func testRedactsSensibleURLsFromDeepLinksTracking() {
        testMiddleware.swallowEvent = true
        sdk.open(URL(string: "fb123456789://authorize#access_token=hastoberedacted")!, options: [:])
        let event = testMiddleware.lastContext?.payload as? TrackPayload
        XCTAssertEqual(event?.event, "Deep Link Opened")
        XCTAssertEqual(event?.properties?["url"] as? String, "fb123456789://authorize#access_token=((redacted/fb-auth-token))")
    }
    
    func testRedactsSensibleURLsFromDeepLinksWithFilters() {
        testMiddleware.swallowEvent = true
        sdk.open(URL(string: "myapp://auth?token=hastoberedacted&other=stuff")!, options: [:])
        let event = testMiddleware.lastContext?.payload as? TrackPayload
        XCTAssertEqual(event?.event, "Deep Link Opened")
        XCTAssertEqual(event?.properties?["url"] as? String, "myapp://auth?token=((redacted/my-auth))&other=stuff")
    }
    
    func testDefaultsSEGQueueToEmptyArray() {
        let integration = sdk.test_integrationsManager()?.test_snapyrIntegration()
        XCTAssertNotNil(integration)
        integration?.test_fileStorage()?.resetAll()
        XCTAssert(integration?.test_queue()?.isEmpty ?? false)
    }
    
    func testDeviceTokenRegistration() {
        func getStringFrom(token: Data) -> String {
            return token.reduce("") { $0 + String(format: "%02.2hhx", $1) }
        }
        
        let deviceToken = GenerateUUIDString()
        let data = deviceToken.data(using: .utf8)
        if let data = data {
            sdk.registeredForRemoteNotifications(withDeviceToken: data)
            let deviceTokenString = getStringFrom(token: data)
            let sdkProvidedToken = sdk.getDeviceToken()
            XCTAssertEqual(deviceTokenString, sdkProvidedToken)
        } else {
            XCTAssertNotNil(data)
        }
    }
    
    func testHandleNotificationImageSuccess() {
        let dummyRequest = getTestPayload()
        guard let payload = (dummyRequest.content.mutableCopy() as? UNMutableNotificationContent) else { XCTFail("No payload found in dummy request") ; return }
        let handleNotificationExpectation = expectation(description: "Test Handle Notification Image Success")
        Snapyr.handleNoticationExtensionRequest(withBestAttempt: payload, originalRequest: dummyRequest, contentHandler: { modifiedContent in
            guard let imageAttachment = modifiedContent.attachments.first,
                  let _ = try? Data(contentsOf: imageAttachment.url) else {
                      XCTFail("Could not fetch image data")
                      handleNotificationExpectation.fulfill()
                      return
                  }
            handleNotificationExpectation.fulfill()
                  
        }, snapyrEnvironment: .dev)
        wait(for: [handleNotificationExpectation], timeout: 5)
    }
    
    func testHandleNotificationImageFailure() {
        let dummyRequest = getTestPayload(invalidURL: true)
        guard let payload = (dummyRequest.content.mutableCopy() as? UNMutableNotificationContent) else { XCTFail("No payload found in dummy request") ; return }
        let handleNotificationExpectation = expectation(description: "Test Handle Notification Image Failure")
        Snapyr.handleNoticationExtensionRequest(withBestAttempt: payload, originalRequest: dummyRequest, contentHandler: { modifiedContent in
            guard let imageAttachment = modifiedContent.attachments.first,
                  let _ = try? Data(contentsOf: imageAttachment.url) else {
                      // success, because content Handler is called
                      handleNotificationExpectation.fulfill()
                      return
                  }
            XCTFail("Image should fail")
            handleNotificationExpectation.fulfill()
        }, snapyrEnvironment: .dev)
        wait(for: [handleNotificationExpectation], timeout: 5)
    }
    
    func testHandleNotificationImageTimeout() {
        let dummyRequest = getTestPayload(invalidURL: true)
        guard let payload = (dummyRequest.content.mutableCopy() as? UNMutableNotificationContent) else { XCTFail("No payload found in dummy request") ; return }
        let handleNotificationExpectation = expectation(description: "Test Handle Notification Image Timeout")
        Snapyr.handleNoticationExtensionRequest(withBestAttempt: payload, originalRequest: dummyRequest, contentHandler: { modifiedContent in
            // success
            handleNotificationExpectation.fulfill()
        }, snapyrEnvironment: .dev)
        wait(for: [handleNotificationExpectation], timeout: 5)
    }
    
    func testEnable() {
        sdk.enable()
        XCTAssertEqual(sdk.test_enabled(), true)
    }
    
    func testDisable() {
        sdk.disable()
        XCTAssertEqual(sdk.test_enabled(), false)
    }
}

