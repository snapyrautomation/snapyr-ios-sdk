//
//  MiddlewareTests.swift
//  Analytics
//
//  Created by Tony Xiao on 1/9/17.
//  Copyright © 2017 Segment. All rights reserved.
//


import Snapyr
import XCTest

// Changing event names and adding custom attributes
let customizeAllTrackCalls = BlockMiddleware { (context, next) in
    if context.eventType == .track {
        next(context.modify { ctx in
            guard let track = ctx.payload as? TrackPayload else {
                return
            }
            let newEvent = "[New] \(track.event)"
            var newProps = track.properties ?? [:]
            newProps["customAttribute"] = "Hello"
            newProps["nullTest"] = NSNull()
            ctx.payload = TrackPayload(
                event: newEvent,
                properties: newProps,
                context: track.context,
                integrations: track.integrations
            )
        })
    } else {
        next(context)
    }
}

// Simply swallows all calls and does not pass events downstream
let eatAllCalls = BlockMiddleware { (context, next) in
}

class SourceMiddlewareTests: XCTestCase {
    
    func testReceivesEvents() {
        let passthrough = PassthroughMiddleware()
        let sdk = getUnitTestSDK(application:nil, sourceMiddleware: [passthrough], destinationMiddleware: [])
        sdk.identify("testUserId1")
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.identify)
        let identify = passthrough.lastContext?.payload as? IdentifyPayload
        XCTAssertEqual(identify?.userId, "testUserId1")
    }
    
    func testModifiesAndPassesEventToNext() {
        let passthrough = PassthroughMiddleware()
        let sourceMiddleware:[Middleware] = [
            customizeAllTrackCalls,
            passthrough,
        ]
        let sdk = getUnitTestSDK(application:nil, sourceMiddleware: sourceMiddleware, destinationMiddleware: [])
        sdk.track("Purchase Success")
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.track)
        let track = passthrough.lastContext?.payload as? TrackPayload
        XCTAssertEqual(track?.event, "[New] Purchase Success")
        XCTAssertEqual(track?.properties?["customAttribute"] as? String, "Hello")
        let isNull = (track?.properties?["nullTest"] is NSNull)
        XCTAssert(isNull)
    }
    
    func testExpectsEventToBeSwallowed() {
        let passthrough = PassthroughMiddleware()
        let sourceMiddleware:[Middleware] = [
            eatAllCalls,
            passthrough,
        ]
        let snapyr = getUnitTestSDK(application:nil, sourceMiddleware: sourceMiddleware, destinationMiddleware: [])
        snapyr.track("Purchase Success")
        XCTAssertNil(passthrough.lastContext)
    }
}

class IntegrationMiddlewareTests: XCTestCase {
    
    func disableTestReceivesEvents() {
        let passthrough = PassthroughMiddleware()
        let destinationMiddleware = [DestinationMiddleware(key: SnapyrIntegrationFactory().key(),
                                                           middleware: [passthrough])]
        let sdk = getUnitTestSDK(application:nil, sourceMiddleware: [], destinationMiddleware: destinationMiddleware)
        sdk.identify("testUserId1")
        
        // pump the runloop until we have a last context.
        // integration middleware is held up until initialization is completed.
        let currentTime = Date()
        while(passthrough.lastContext == nil && currentTime < currentTime + 60) {
            sleep(1);
        }
        
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.identify)
        let identify = passthrough.lastContext?.payload as? IdentifyPayload
        XCTAssertEqual(identify?.userId, "testUserId1")
    }
    
    func disableTestModifiesAndPassesEventToNext() {
        let passthrough = PassthroughMiddleware()
        let destinationMiddleware = [DestinationMiddleware(key: SnapyrIntegrationFactory().key(),
                                                           middleware: [customizeAllTrackCalls, passthrough])]
        let sdk = getUnitTestSDK(application:nil, sourceMiddleware: [], destinationMiddleware: destinationMiddleware)
        sdk.track("Purchase Success")
        
        // pump the runloop until we have a last context.
        // integration middleware is held up until initialization is completed.
        let currentTime = Date()
        while(passthrough.lastContext == nil && currentTime < currentTime + 60) {
            sleep(1)
        }
        
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.track)
        let track = passthrough.lastContext?.payload as? TrackPayload
        XCTAssertEqual(track?.event, "[New] Purchase Success")
        XCTAssertEqual(track?.properties?["customAttribute"] as? String, "Hello")
        let isNull = (track?.properties?["nullTest"] is NSNull)
        XCTAssert(isNull, "Should be true")
    }
    
    func disableTestExpectsEventToBeSwallowedIfOtherIsNotCalled() {
        // Since we're testing that an event is dropped, the previously used run loop pump won't work here.
        var initialized = false
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: SnapyrSDKIntegrationDidStart), object: nil, queue: nil) { (notification) in
            initialized = true
        }
        let passthrough = PassthroughMiddleware()
        let destinationMiddleware = [DestinationMiddleware(key: SnapyrIntegrationFactory().key(),
                                                           middleware: [eatAllCalls, passthrough])]
        let sdk = getUnitTestSDK(application:nil, sourceMiddleware: [], destinationMiddleware: destinationMiddleware)
        sdk.track("Purchase Success")
        
        while (!initialized) {
            sleep(1)
        }
        XCTAssertNil(passthrough.lastContext)
    }
}
