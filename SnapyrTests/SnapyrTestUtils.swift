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
    static var apiHost = "dev-engine.snapyrdev.net"
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


func getUnitTestSDK (
    application: TestApplication?,
    sourceMiddleware: [Middleware],
    destinationMiddleware: [DestinationMiddleware]) -> Snapyr {
    
    let configuration = SnapyrConfiguration(writeKey: "RSLG3AdcWnHBvqxdGvZJ6FtkNAmudjtX")
    configuration.trackApplicationLifecycleEvents = true
    configuration.flushAt = 1
    configuration.errorHandler = failOnError
    configuration.sourceMiddleware = sourceMiddleware
    configuration.destinationMiddleware = destinationMiddleware
    configuration.application = application
    configuration.trackDeepLinks = true
    configuration.payloadFilters["(myapp://auth\\?token=)([^&]+)"] = "$1((redacted/my-auth))"
    let sdk = Snapyr(configuration: configuration)
    let integrationManager = sdk.test_integrationsManager()
    let mockHttpClient = MockHTTPClient()
    integrationManager?.test_setHttpClient(httpClient:mockHttpClient)
    return sdk
}


