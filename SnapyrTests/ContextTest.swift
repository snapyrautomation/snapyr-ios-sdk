//
//  ContextTest.swift
//  Analytics
//
//  Created by Tony Xiao on 9/20/16.
//  Copyright © 2016 Segment. All rights reserved.
//

import Snapyr
import XCTest

class ContextTests: XCTestCase {
    
    var sdk: Snapyr!
    
    override func setUp() {
        super.setUp()
        sdk = getUnitTestSDK(sourceMiddleware: [], destinationMiddleware: [])
    }
    
    func testThrowsWhenUsedIncorrectly() {
        var context: Context?
        var exception: NSException?
        
        exception = objc_tryCatch {
            context = Context()
        }
        
        XCTAssertNil(context)
        XCTAssertNotNil(exception)
    }
    
    func testInitializedCorrectly() {
        let context = Context(sdk: sdk)
        XCTAssertEqual(context.sdk, sdk)
        XCTAssertEqual(context.eventType, EventType.undefined)
    }
    
    func testAcceptsModifications() {
        let context = Context(sdk: sdk)
        
        let newContext = context.modify { context in
            context.payload = TrackPayload()
            context.payload?.userId = "sloth"
            context.eventType = .track
        }
        XCTAssertEqual(newContext.payload?.userId, "sloth")
        XCTAssertEqual(newContext.eventType,  EventType.track)
    }
    
    func testModifiesCopyInDebugMode() {
        let context = Context(sdk: sdk).modify { context in
            context.debug = true
            context.eventType = .track
        }
        XCTAssertEqual(context.debug, true)
        
        let newContext = context.modify { context in
            context.eventType = .identify
        }
        XCTAssertNotEqual(context, newContext)
        XCTAssertEqual(newContext.eventType, .identify)
        XCTAssertEqual(context.eventType, .track)
    }
    
    func testModifiesSelfInNonDebug() {
        let context = Context(sdk: sdk).modify { context in
            context.debug = false
            context.eventType = .track
        }
        XCTAssertFalse(context.debug)
        
        let newContext = context.modify { context in
            context.eventType = .identify
        }
        XCTAssertEqual(context, newContext)
        XCTAssertEqual(newContext.eventType, .identify)
        XCTAssertEqual(context.eventType, .identify)
    }
}
