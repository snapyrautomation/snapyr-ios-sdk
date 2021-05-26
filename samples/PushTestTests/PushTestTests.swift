//
//  PushTestTests.swift
//  PushTestTests
//
//  Created by Anthony Putignano on 5/3/21.
//

import XCTest
@testable import PushTestExtension

class PushTestTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testImageDownload() throws {
        print("testing image download...")

        let pushUtilities = PushUtilities();
        
        guard let url = URL(string: "https://skookle.com/screen_shot.png") else {
            XCTFail("Could not parse url for image.")
            return
        }
        
        print("downloading image...")
        pushUtilities.downloadImage(forURL: url)  { result in
            guard let image = try? result.get() else {
                return
            }
            XCTAssertNotNil(image)
            print("saving attachment...")
            let fileUrl = pushUtilities.saveImageAttachment(image: image, forIdentifier: "image.png")
            print("the url = \(fileUrl!)")
        }
        for _ in 1...2 {
            sleep(5)
        }
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
