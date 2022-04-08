import Snapyr
import XCTest

class SwizzlingTests: XCTestCase {
	fileprivate var mockAppDelegate: MockAppDelegate!
	var proxy: NotificationsProxy!
	var imps: MockProxyImplementations!
    override func setUpWithError() throws {
		mockAppDelegate = MockAppDelegate()
		imps = MockProxyImplementations()
		proxy = NotificationsProxy.shared()
		proxy.unswizzleMethodsIfPossible()
		proxy.proxyImplementations = imps
		proxy.customAppDelegate = mockAppDelegate
		proxy.swizzleMethodsIfPossible()
    }

    override func tearDownWithError() throws {
		proxy.unswizzleMethodsIfPossible()
		proxy.customAppDelegate = nil
		proxy.proxyImplementations = nil
		imps = nil
		mockAppDelegate = nil
		proxy = nil
    }

    func testSwizzle() throws {
		/*
		 NOTE: methods MUST be called from mock app delegate as `UIApplicationDelegate` (in real app, methods are called from it),
		 otherwise swizzler won't detect it, so here I'm creating constant `uiMockAppDelegate` for calling methods
		 */
		let uiMockAppDelegate = mockAppDelegate as UIApplicationDelegate
		
		// original implementation expectations
		let originalRegisterToAPNSExpectation = expectation(description: "Original `didRegisterForRemoteNotificationsWithDeviceToken` implementation (from 'app delegate') call")
		let originalContinueUserActivityExpectation = expectation(description: "Original `continue userActivity` implementation (from 'app delegate') call")
		let originalFailToRegisterToAPNSExpectation = expectation(description: "Original `didFailToRegisterForRemoteNotificationsWithError` implementation (from 'app delegate') call")
		let originalOpenUrlExpectation = expectation(description: "Original `openURL` implementation (from 'app delegate') call")
		
		fulfillExpectationOnBlockCall(&mockAppDelegate.onRegisterToAPNS, expectation: originalRegisterToAPNSExpectation)
		fulfillExpectationOnBlockCall(&mockAppDelegate.onContinueUserActivity, expectation: originalContinueUserActivityExpectation)
		fulfillExpectationOnBlockCall(&mockAppDelegate.onFailToRegisterToAPNS, expectation: originalFailToRegisterToAPNSExpectation)
		fulfillExpectationOnBlockCall(&mockAppDelegate.onOpenURL, expectation: originalOpenUrlExpectation)

		
		// custom implementation expectations
		let customRegisterToAPNSExpectation = expectation(description: "Custom `didRegisterForRemoteNotificationsWithDeviceToken` implementation (from 'app delegate') call")
		let customContinueUserActivityExpectation = expectation(description: "Custom `continue userActivity` implementation (from 'app delegate') call")
		let customFailToRegisterToAPNSExpectation = expectation(description: "Custom `didFailToRegisterForRemoteNotificationsWithError` implementation (from 'app delegate') call")
		let customOpenUrlExpectation = expectation(description: "Custom `openURL` implementation (from 'app delegate') call")

		fulfillExpectationOnBlockCall(&imps.didRegisteredForAPNS, expectation: customRegisterToAPNSExpectation)
		fulfillExpectationOnBlockCall(&imps.continueUserActivity, expectation: customContinueUserActivityExpectation)
		fulfillExpectationOnBlockCall(&imps.didFailToRegisterForAPNS, expectation: customFailToRegisterToAPNSExpectation)
		fulfillExpectationOnBlockCall(&imps.openURL, expectation: customOpenUrlExpectation)
		
		
		/*
		 NOTE: just passing random stuff to methods(except for `UIApplication`, because there can be only one instance of it), they aren't used,
		 the main need is to test that the methods are called at all
		 */
		uiMockAppDelegate.application?(.shared, didRegisterForRemoteNotificationsWithDeviceToken: "testapnstokendontuseitanywhere".data(using: .utf8)!)
		_ = uiMockAppDelegate.application?(.shared, continue: NSUserActivity(activityType: "test"), restorationHandler: {_ in})
		uiMockAppDelegate.application?(.shared, didFailToRegisterForRemoteNotificationsWithError: NSError(domain: "snapyr.dummyErrorDomain", code: 1))
		_ = uiMockAppDelegate.application?(.shared, open: URL(string: "https://test")!)
		
		wait(for: [
			// original implementation expectations
			originalRegisterToAPNSExpectation,
			originalContinueUserActivityExpectation,
			originalFailToRegisterToAPNSExpectation,
			originalOpenUrlExpectation,
			
			// custom implementation expectations
			customRegisterToAPNSExpectation,
			customContinueUserActivityExpectation,
			customFailToRegisterToAPNSExpectation,
			customOpenUrlExpectation
		], timeout: 10)
    }
	
	func testUnswizzle() {
		// unswizzle methods first
		proxy.unswizzleMethodsIfPossible()
		
		
		/*
		 NOTE: methods MUST be called from mock app delegate as `UIApplicationDelegate` (in real app, methods are called from it),
		 otherwise swizzler won't detect it (and test will be always succeded), so here I'm creating constant `uiMockAppDelegate` for calling methods
		 */
		let uiMockAppDelegate = mockAppDelegate as UIApplicationDelegate
		
		// original implementation expectations
		let originalRegisterToAPNSExpectation = expectation(description: "Original `didRegisterForRemoteNotificationsWithDeviceToken` implementation (from 'app delegate') call")
		let originalContinueUserActivityExpectation = expectation(description: "Original `continue userActivity` implementation (from 'app delegate') call")
		let originalFailToRegisterToAPNSExpectation = expectation(description: "Original `didFailToRegisterForRemoteNotificationsWithError` implementation (from 'app delegate') call")
		let originalOpenUrlExpectation = expectation(description: "Original `openURL` implementation (from 'app delegate') call")
		
		fulfillExpectationOnBlockCall(&mockAppDelegate.onRegisterToAPNS, expectation: originalRegisterToAPNSExpectation)
		fulfillExpectationOnBlockCall(&mockAppDelegate.onContinueUserActivity, expectation: originalContinueUserActivityExpectation)
		fulfillExpectationOnBlockCall(&mockAppDelegate.onFailToRegisterToAPNS, expectation: originalFailToRegisterToAPNSExpectation)
		fulfillExpectationOnBlockCall(&mockAppDelegate.onOpenURL, expectation: originalOpenUrlExpectation)
		
		
		// custom implementation expectations
		let customRegisterToAPNSExpectation = expectation(description: "Custom `didRegisterForRemoteNotificationsWithDeviceToken` implementation (from 'app delegate') not called")
		let customContinueUserActivityExpectation = expectation(description: "Custom `continue userActivity` implementation (from 'app delegate') not called")
		let customFailToRegisterToAPNSExpectation = expectation(description: "Custom `didFailToRegisterForRemoteNotificationsWithError` implementation (from 'app delegate') not called")
		let customOpenUrlExpectation = expectation(description: "Custom `openURL` implementation (from 'app delegate') not called")
		
		fulfillExpectationOnBlockCallTimeout(&imps.didRegisteredForAPNS, expectation: customRegisterToAPNSExpectation, timeout: 5)
		fulfillExpectationOnBlockCallTimeout(&imps.continueUserActivity, expectation: customContinueUserActivityExpectation, timeout: 5)
		fulfillExpectationOnBlockCallTimeout(&imps.didFailToRegisterForAPNS, expectation: customFailToRegisterToAPNSExpectation, timeout: 5)
		fulfillExpectationOnBlockCallTimeout(&imps.openURL, expectation: customOpenUrlExpectation, timeout: 5)
		
		
		/*
		 NOTE: just passing random stuff to methods(except for `UIApplication`, because there can be only one instance of it), they aren't used,
		 the main need is to test that the methods are called at all
		 */
		uiMockAppDelegate.application?(.shared, didRegisterForRemoteNotificationsWithDeviceToken: "testapnstokendontuseitanywhere".data(using: .utf8)!)
		_ = uiMockAppDelegate.application?(.shared, continue: NSUserActivity(activityType: "test"), restorationHandler: {_ in})
		uiMockAppDelegate.application?(.shared, didFailToRegisterForRemoteNotificationsWithError: NSError(domain: "snapyr.dummyErrorDomain", code: 1))
		_ = uiMockAppDelegate.application?(.shared, open: URL(string: "https://test")!)
		
		wait(for: [
			// original implementation expectations
			originalRegisterToAPNSExpectation,
			originalContinueUserActivityExpectation,
			originalFailToRegisterToAPNSExpectation,
			originalOpenUrlExpectation,
			
			// custom implementation expectations
			customRegisterToAPNSExpectation,
			customContinueUserActivityExpectation,
			customFailToRegisterToAPNSExpectation,
			customOpenUrlExpectation
		], timeout: 15)
	}
	
	func fulfillExpectationOnBlockCallTimeout(_ block: inout (() -> Void)?, expectation: XCTestExpectation, timeout: TimeInterval) {
		var blockCalled = false
		block = {
			blockCalled = true
		}
		
		waitUntil(blockCalled, timeout: timeout) { timeout in
			if timeout {
				expectation.fulfill()
			}
		}
	}
	
	func fulfillExpectationOnBlockCall(_ block: inout (() -> Void)?, expectation: XCTestExpectation) {
		block = {
			expectation.fulfill()
		}
	}
}









/// Mock `AppDelegate` for swizzling testing
fileprivate
class MockAppDelegate: NSObject, UIApplicationDelegate {
	var onRegisterToAPNS: (() -> Void)?
	var onContinueUserActivity: (() -> Void)?
	var onFailToRegisterToAPNS: (() -> Void)?
	var onOpenURL: (() -> Void)?
	
	
	func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		print(#function)
		onRegisterToAPNS?()
	}
	
	func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
		print(#function)
		onContinueUserActivity?()
		return true
	}
	
	func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
		print(#function)
		onFailToRegisterToAPNS?()
	}
	
	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
		print(#function)
		onOpenURL?()
		return true
	}
}
