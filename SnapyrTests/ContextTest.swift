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
    
    var snapyr: Snapyr!
    
    override func setUp() {
        super.setUp()
        let config = getUnitTestConfiguration ()
        snapyr = Snapyr(configuration: config)
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
        let context = Context(sdk: snapyr)
        XCTAssertEqual(context.sdk, snapyr)
        XCTAssertEqual(context.eventType, EventType.undefined)
    }
    
    func testAcceptsModifications() {
        let context = Context(sdk: snapyr)
        
        let newContext = context.modify { context in
            context.payload = TrackPayload()
            context.payload?.userId = "sloth"
            context.eventType = .track
        }
        XCTAssertEqual(newContext.payload?.userId, "sloth")
        XCTAssertEqual(newContext.eventType,  EventType.track)
    }
    
    func testModifiesCopyInDebugMode() {
        let context = Context(sdk: snapyr).modify { context in
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
        let context = Context(sdk: snapyr).modify { context in
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
