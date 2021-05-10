@testable import Snapyr
import XCTest

class EndToEndTests: XCTestCase {
    func testTrack() {
        let configuration = SnapyrConfiguration(writeKey: "pzz0y35cYIGNW1bENFowkNuvMhaGha9A")
        configuration.flushAt = 1
        Snapyr.setup(with: configuration)
        let snapyr = Snapyr.shared()
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
        snapyr.flush()
        wait(for: [expectation], timeout: 6.0)
    }
}
