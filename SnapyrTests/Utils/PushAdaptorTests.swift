//
//  PushAdaptorTests.swift
//  SnapyrTests
//
//  Created by Brian O'Neill on 5/27/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//

import Foundation
@testable import Snapyr
import XCTest

class PushAdaptorTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testPushAdaptor() {
        let pushAdaptor = PushAdaptor()
        guard
            let pathString = Bundle(for: type(of: self)).path(forResource: "sdk", ofType: "json"),
            let jsonString = try? String(contentsOfFile: pathString, encoding: .utf8),
            let jsonData = jsonString.data(using: .utf8)
        else {
            fatalError("sdk.json not found")
        }
        
        guard let sdkConfig = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String:Any] else {
            fatalError("Unable to convert sdk.json to JSON dictionary")
        }

        print("sdkConfig : [\(sdkConfig)]")
        let categories = pushAdaptor.parseCategories(sdkConfig)
        guard
            let category = categories?[0] as? PushCategory
        else {
            XCTFail("category not parsed")
            return
        }
        XCTAssertEqual(category.actions.count, 3)
    }
}
