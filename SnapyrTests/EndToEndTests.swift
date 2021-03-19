@testable import Snapyr
import XCTest

class EndToEndTests: XCTestCase {
    
    var snapyr: Snapyr!
    var configuration: SnapyrConfiguration!
    
    override func setUp() {
        super.setUp()
        
        // Write Key for https://app.segment.com/segment-libraries/sources/analytics_ios_e2e_test/overview
        configuration = SnapyrConfiguration(writeKey: "3VxTfPsVOoEOSbbzzbFqVNcYMNu2vjnr")
        configuration.flushAt = 1

        Snapyr.setup(with: configuration)

        snapyr = Snapyr.shared()
    }
    
    override func tearDown() {
        super.tearDown()
        
        snapyr.reset()
    }
    
    func testTrack() {
        let uuid = UUID().uuidString
        let expectation = XCTestExpectation(description: "SnapyrRequestDidSucceed")
        
        configuration.experimental.rawSnapyrModificationBlock = { data in
            if let properties = data["properties"] as? Dictionary<String, Any?>,
                let tempUUID = properties["id"] as? String, tempUUID == uuid {
                expectation.fulfill()
            }
            return data
        }

        snapyr.track("E2E Test", properties: ["id": uuid])
        
        wait(for: [expectation], timeout: 2.0)
    }
}
