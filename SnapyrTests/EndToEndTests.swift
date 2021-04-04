@testable import Snapyr
import XCTest

class EndToEndTests: XCTestCase {
    
    var snapyr: Snapyr!
    var configuration: SnapyrConfiguration!
    
    override func setUp() {
        super.setUp()
        //configuration = SnapyrConfiguration(writeKey: "3VxTfPsVOoEOSbbzzbFqVNcYMNu2vjnr")
        configuration = SnapyrConfiguration(writeKey: "RSLG3AdcWnHBvqxdGvZJ6FtkNAmudjtX")
        configuration.flushAt = 1
        Snapyr.setup(with: configuration)
        snapyr = Snapyr.shared()
        sleep(5)
    }
    
    override func tearDown() {
        super.tearDown()
        snapyr.reset()
    }
    
    func disableTestTrack() {
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
        wait(for: [expectation], timeout: 5.0)
    }
    
    func disableTestSetPushNotificationToken(){
        let configuration = SnapyrConfiguration(writeKey: "RSLG3AdcWnHBvqxdGvZJ6FtkNAmudjtX")
        Snapyr.debug(true)
        Snapyr.setup(with: configuration)
        Snapyr.shared().identify("ubi42")
        print("======================================================================")
        let token = "FB887DD3447C13052588C4518DF4FC4A0D6A17D9E743645FF1B914764CC9CC0F"
        snapyr.setPushNotificationToken(token)
    }
    

}
