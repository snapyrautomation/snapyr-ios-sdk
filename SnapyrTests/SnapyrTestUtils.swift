//
//  SnapyrTestUtils.swift
//  Snapyr
//
//  Created by Brian O'Neill on 5/13/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//

import Foundation
import XCTest

struct TestVariables {
    static var apiHost = "dev-engine.snapyr.com"
}

func failOnError (code: Int, message: String, data: Optional<Data>) {
    if let unwrapped = data {
        let body = String(decoding: unwrapped, as: UTF8.self)
        print("shit happened = \(code):\(message) [\(body)")
    } else {
        print("shit happened = \(code):\(message)")
    }
    XCTAssertEqual(0, 1)
}


func getUnitTestConfiguration () -> SnapyrConfiguration {
    let configuration = SnapyrConfiguration(writeKey: "RSLG3AdcWnHBvqxdGvZJ6FtkNAmudjtX")
    configuration.useMocks = true
    configuration.flushAt = 1
    configuration.errorHandler = failOnError
    return configuration
}

