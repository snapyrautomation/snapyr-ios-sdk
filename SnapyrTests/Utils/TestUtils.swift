//
//  TestUtils.swift
//  Analytics
//
//  Created by Tony Xiao on 9/19/16.
//  Copyright © 2016 Segment. All rights reserved.
//

// TODO: Uncomment these tests using Nocilla and get rid of Nocilla.

/*
import Nocilla
 */
import Snapyr
import XCTest

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

class PassthroughMiddleware: Middleware {
    var lastContext: Context?

    func context(_ context: Context, next: @escaping SnapyrMiddlewareNext) {
        lastContext = context;
        next(context)
    }
}

class TestMiddleware: Middleware {
    var lastContext: Context?
    var swallowEvent = false
    func context(_ context: Context, next: @escaping SnapyrMiddlewareNext) {
        lastContext = context
        if !swallowEvent {
            next(context)
        }
    }
}

extension Snapyr {
    func test_integrationsManager() -> IntegrationsManager? {
        return self.value(forKey: "integrationsManager") as? IntegrationsManager
    }
    func test_enabled() -> Bool? {
        return self.value(forKey: "enabled") as? Bool
    }
}

extension IntegrationsManager {
    func test_integrations() -> [String: Integration]? {
        return self.value(forKey: "integrations") as? [String: Integration]
    }
    func test_snapyrIntegration() -> SnapyrIntegration? {
        return self.test_integrations()?["Snapyr"] as? SnapyrIntegration
    }
    func test_setCachedSettings(settings: NSDictionary) {
        self.perform(Selector(("setCachedSettings:")), with: settings)
    }
    func test_setHttpClient(httpClient: HTTPClient) -> Void {
        self.setValue(httpClient, forKey:"httpClient")
    }
    func test_setActionIdMap(_ data: NSMutableDictionary) {
        self.setValue(data, forKey: "actionIdMap")
    }
}

extension SnapyrIntegration {
    func test_fileStorage() -> FileStorage? {
        return self.value(forKey: "fileStorage") as? FileStorage
    }
    func test_referrer() -> [String: AnyObject]? {
        return self.value(forKey: "referrer") as? [String: AnyObject]
    }
    func test_userId() -> String? {
        return self.value(forKey: "userId") as? String
    }
    func test_traits() -> [String: AnyObject]? {
        return self.value(forKey: "traits") as? [String: AnyObject]
    }
    func test_flushTimer() -> Timer? {
        return self.value(forKey: "flushTimer") as? Timer
    }
    func test_batchRequest() -> URLSessionUploadTask? {
        return self.value(forKey: "batchRequest") as? URLSessionUploadTask
    }
    func test_queue() -> [AnyObject]? {
        return self.value(forKey: "queue") as? [AnyObject]
    }
    func test_dispatchBackground(block: @escaping @convention(block) () -> Void) {
        self.perform(Selector(("dispatchBackground:")), with: block)
    }
}

class TestApplication: NSObject, ApplicationProtocol {
    class BackgroundTask {
        let identifier: Int
        var isEnded = false
    
        init(identifier: Int) {
            self.identifier = identifier
        }
    }

    var backgroundTasks = [BackgroundTask]()
  
    // MARK: - ApplicationProtocol
    #if os(macOS)
    var delegate: NSApplicationDelegate? = nil
    #else
    var delegate: UIApplicationDelegate? = nil
    #endif
    
    func snapyr_beginBackgroundTask(withName taskName: String?, expirationHandler handler: (() -> Void)? = nil) -> UInt {
        let backgroundTask = BackgroundTask(identifier: (backgroundTasks.map({ $0.identifier }).max() ?? 0) + 1)
        backgroundTasks.append(backgroundTask)
        return UInt(backgroundTask.identifier)
    }
  
    func snapyr_endBackgroundTask(_ identifier: UInt) {
        guard let index = backgroundTasks.firstIndex(where: { $0.identifier == identifier }) else { return }
        backgroundTasks[index].isEnded = true
    }
}

extension XCTestCase {
    
    func expectUntil(_ time: TimeInterval, expression: @escaping @autoclosure () throws -> Bool) {
        let expectation = self.expectation(description: "Expect Until")
        DispatchQueue.global().async {
            while (true) {
                if try! expression() {
                    expectation.fulfill()
                    return
                }
                usleep(500) // try every half second
            }
        }
        wait(for: [expectation], timeout: time)
    }
	
	func waitUntil(_ condition: @escaping @autoclosure () throws -> Bool, completion: @escaping ()->Void) {
		DispatchQueue.global().async {
			while (true) {
				if try! condition() {
					completion()
					return
				}
				usleep(500) // try every half second
			}
		}
	}
	
	func waitUntil(_ condition: @escaping @autoclosure () throws -> Bool, timeout: TimeInterval, completion: @escaping (Bool)->Void) {
		DispatchQueue.global().async {
			let startDate = Date()
			while (true) {
				if try! condition() {
					completion(false)
					return
				}
				let time = Date().timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
				if time > timeout {
					completion(true)
					return
				}
				usleep(500) // try every half second
			}
		}
	}
}

