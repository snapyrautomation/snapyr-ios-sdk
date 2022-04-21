import Snapyr
import XCTest
class IntegrationsManagerTest: XCTestCase {
	var integration: IntegrationsManager!
    
	override func setUpWithError() throws {
		let sdk = getUnitTestSDK(application: nil, sourceMiddleware: [], destinationMiddleware: [])
		let client = MockHTTPClient()
		
		integration = IntegrationsManager(sdk: sdk)
		integration.test_setHttpClient(httpClient: client)
		integration.test_setCachedSettings(settings: [:])
	}
	
	func testNotificationAction() {
		let expectation = expectation(description: "testNotificationAction")
		integration.refreshSettings()
		waitUntil(self.integration.test_cachedSettings() != [:]) {
			// "notification tapped"
			let notifAction = "22c6d726-42d4-4339-860d-59714d3bcd46"
			let deepLink = self.integration.getDeepLink(forActionId: notifAction)
			XCTAssertEqual(deepLink?.absoluteString, "http://snooze.com")
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 10)
	}
	
    func testValidValueTypesInIntegrationEnablementFlags() {
        let exception = objc_tryCatch {
            IntegrationsManager.isIntegration("comScore", enabledInOptions: ["comScore": ["blah": 1]])
            IntegrationsManager.isIntegration("comScore", enabledInOptions: ["comScore": true])
        }
        
        XCTAssertNil(exception)
    }
    
    func testAssertsWhenInvalidValueTypesUsedIntegrationEnablement() {
        let exception = objc_tryCatch {
            IntegrationsManager.isIntegration("comScore", enabledInOptions: ["comScore": "blah"])
        }
        
        XCTAssertNotNil(exception)
    }
    
    func testAssertsWhenInvalidValueTypesIntegrationEnableFlags() {
        let exception = objc_tryCatch {
            // we don't accept array's as values.
            IntegrationsManager.isIntegration("comScore", enabledInOptions: ["comScore": ["key", 1]])
        }
        
        XCTAssertNotNil(exception)
    }
    
    func testPullsValidIntegrationDataWhenSupplied() {
        let enabled = IntegrationsManager.isIntegration("comScore", enabledInOptions: ["comScore": true])
        XCTAssert(enabled)
    }
    
    func testFallsBackCorrectlyWhenNotSpecified() {
        let enabled = IntegrationsManager.isIntegration("comScore", enabledInOptions: ["all": true])
        XCTAssert(enabled)
        let allEnabled = IntegrationsManager.isIntegration("comScore", enabledInOptions: ["All": true])
        XCTAssert(allEnabled)
    }
    
    func testReturnsTrueWhenThereisNoPlan() {
        let enabled = IntegrationsManager.isTrackEvent("hello world", enabledForIntegration: "Amplitude", inPlan:[:])
        XCTAssert(enabled)
    }
    
    func testReturnsTrueWhenPlanIsEmpty() {
        let enabled = IntegrationsManager.isTrackEvent("hello world", enabledForIntegration: "Mixpanel", inPlan:["track":[:]])
        XCTAssert(enabled)
    }
    
    func testReturnsTrueWhenPlanEnablesEvent() {
        let enabled = IntegrationsManager.isTrackEvent("hello world", enabledForIntegration: "Mixpanel", inPlan:["track":["hello world":["enabled":true]]])
        XCTAssert(enabled)
    }
    
    func testReturnsFalseWhenPlanDisablesEvent() {
        let enabled = IntegrationsManager.isTrackEvent("hello world", enabledForIntegration: "Amplitude", inPlan:["track":["hello world":["enabled":false]]])
        XCTAssertFalse(enabled)
    }
    
    func testReturnsTrueForSnapyrIntegrationWhenDisablesEvent() {
        let enabled = IntegrationsManager.isTrackEvent("hello world", enabledForIntegration: "Snapyr", inPlan:["track":["hello world":["enabled":false]]])
        XCTAssert(enabled)
    }
    
    func testReturnsTrueWhenPlanEnablesEventForIntegration() {
        let enabled = IntegrationsManager.isTrackEvent("hello world", enabledForIntegration: "Mixpanel", inPlan:["track":["hello world":["enabled":true, "integrations":["Mixpanel":true]]]])
        XCTAssert(enabled)
    }
    
    func testReturnsFalseWhenPlanDisablesEventForIntegration() {
        let enabled = IntegrationsManager.isTrackEvent("hello world", enabledForIntegration: "Mixpanel", inPlan:["track":["hello world":["enabled":true, "integrations":["Mixpanel":false]]]])
        XCTAssertFalse(enabled)
    }
    
    func testReturnsFalseWhenPlanDisablesNewEvents() {
        let enabled = IntegrationsManager.isTrackEvent("hello world", enabledForIntegration: "Mixpanel", inPlan:["track":["__default":["enabled":false]]])
        XCTAssertFalse(enabled)
    }
    
    func testReturnsUsesEventPlanRatherOverDefaults() {
        let enabled = IntegrationsManager.isTrackEvent("hello world", enabledForIntegration: "Mixpanel", inPlan:["track":["__default":["enabled":false],"hello world":["enabled":true]]])
        XCTAssert(enabled)
    }

}
