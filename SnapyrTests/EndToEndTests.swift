@testable import Snapyr
import XCTest

class EndToEndTests: XCTestCase {
    var snapyr: Snapyr!
    var configuration: SnapyrConfiguration!
    
    override func setUp() {
        super.setUp()
        self.configuration = SnapyrConfiguration(writeKey: "RSLG3AdcWnHBvqxdGvZJ6FtkNAmudjtX")
        self.configuration.flushAt = 1
        Snapyr.debug(true)
        Snapyr.setup(with: self.configuration)
        self.snapyr = Snapyr.shared()
    }
    
    override func tearDown() {
        super.tearDown()
        self.snapyr.reset()
    }
    
    func testTrack() {
        let uuid = UUID().uuidString
        let expectation = XCTestExpectation(description: "SnapyrRequestDidSucceed")
        let integrations = snapyr.bundledIntegrations()
        print("======================================================================")
        print(integrations)
        print("======================================================================")

        self.configuration.experimental.rawSnapyrModificationBlock = { data in
            if let properties = data["properties"] as? Dictionary<String, Any?>,
                let tempUUID = properties["id"] as? String, tempUUID == uuid {
                expectation.fulfill()
            }
            let integrations = self.snapyr.bundledIntegrations()
            print("======================================================================")
            print("Integrations after send = [\(integrations)]")
            print("======================================================================")
            return data
        }
        Snapyr.shared().refreshSettings()
        self.snapyr.track("E2E Test", properties: ["id": uuid])
        self.snapyr.flush()
        Snapyr.shared().refreshSettings()
        self.snapyr.track("E2E Test", properties: ["id": uuid])
        Snapyr.shared().refreshSettings()

        Snapyr.shared().identify("ubi42")
        print("======================================================================")
        let token = "FB887DD3447C13052588C4518DF4FC4A0D6A17D9E743645FF1B914764CC9CC0F"
        snapyr.setPushNotificationToken(token)
        wait(for: [expectation], timeout: 20.0)
    }
}
