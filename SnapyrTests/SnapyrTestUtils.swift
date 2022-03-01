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
    static var apiHost = "engine.snapyr.com"
}

func failOnError (code: Int, message: String, data: Optional<Data>) {
    if let unwrapped = data {
        let body = String(decoding: unwrapped, as: UTF8.self)
        print("shit happened = \(code):\(message) [\(body)")
    } else {
        print("shit happened = \(code):\(message)")
    }
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

func getTestPayload(invalidURL: Bool = false) -> UNNotificationRequest {
    let c = UNMutableNotificationContent()
    c.title = "Push #1"
    c.body = "Tap a button to do awesome stuff now!"
    c.userInfo = getTestUserInfo(invalidURL: invalidURL)
    return UNNotificationRequest.init(identifier: "test_id", content: c, trigger: nil)
}

func getTestUserInfo(invalidURL: Bool = false) -> [String: Any] {
    return [
        "snapyr": [
            "deepLinkUrl": "snapyrrunner://test/reachedAScoreOf/11",
            "imageUrl": invalidURL ? "https://blah.com" : "https://images-na.ssl-images-amazon.com/images/S/pv-target-images/fb1fd46fbac48892ef9ba8c78f1eb6fa7d005de030b2a3d17b50581b2935832f._RI_.jpg",
            "pushTemplate": [
                "id": "0f819332-2c27-4b99-bc87-325cca7b724a",
                "modified": "2022-01-21T16:28:40.626Z"
            ],
            "actionToken": "abc1234562"
        ]
    ]
}
