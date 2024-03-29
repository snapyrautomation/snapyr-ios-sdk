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
    var passthrough: PassthroughMiddleware!
    var sdk: Snapyr!
    
    override func setUp() {
        super.setUp()
        passthrough = PassthroughMiddleware()
        sdk = getUnitTestSDK(application:nil, sourceMiddleware: [passthrough], destinationMiddleware: [])
    }
    
    override func tearDown() {
        super.tearDown()
        sdk.reset()
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
