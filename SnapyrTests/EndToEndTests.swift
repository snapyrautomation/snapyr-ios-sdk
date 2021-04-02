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
        snapyr.flush()
        wait(for: [expectation], timeout: 5.0)
    }
    
    /*
     {
       "messageId": "4ad9a1e3-a667-4184-ae57-760f08e8963a",
       "batch": [
         {
           "type": "track",
           "messageId": "483691a6-55d5-40f2-a046-aa0b3946d49b",
           "userId": "ubi42",
           "event": "snapyr.hidden.apnTokenSet",
           "timestamp": "2020-09-22T19:00:02.733148-04:00",
           "context": {
             "sdkMeta": {
               "platform": "Android",
               "channelId": "6e6e8689-b25d-46b3-a924-7682ba7e6d94"
             }
           },
           "properties": {
             "token": "FB887DD3447C13052588C4518DF4FC4A0D6A17D9E743645FF1B914764CC9CC0F"
           }
         }
       ]
     }
     **/
    func testSetPushNotificationToken(){
        let expectation = XCTestExpectation(description: "SnapyrRequestDidSucceed")
        let configuration = SnapyrConfiguration(writeKey: "RSLG3AdcWnHBvqxdGvZJ6FtkNAmudjtX")
        Snapyr.debug(true)
        Snapyr.setup(with: configuration)
        Snapyr.shared().identify("ubi42")
        print("======================================================================")
        let token = "FB887DD3447C13052588C4518DF4FC4A0D6A17D9E743645FF1B914764CC9CC0F"
        snapyr.setPushNotificationToken(token)
        wait(for: [expectation], timeout: 5.0)
    }
    

}
