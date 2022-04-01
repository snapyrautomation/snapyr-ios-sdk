
import XCTest
import Snapyr

class LoggerTests: XCTestCase {
    var logger: SnapyrLogger!
    override func setUpWithError() throws {
        logger = .init()
        logger.setHTTPClient(.init())
        logger.setShowDebugLogs(true)
        logger.setWriteLogsToFile(true)
    }

    override func tearDownWithError() throws {
        logger = nil
    }

    func testLog() throws {
        let logMessage = "Test log msg"
        logger.logSLog(logMessage)
        guard let logFileUrl = logger.logFileUrl() else {
            XCTFail("No log file url")
            return
        }
        let data = try Data(contentsOf: logFileUrl)
        let string = String(data: data, encoding: .utf8)
        XCTAssertNotNil(string)
        XCTAssertEqual(string?.contains(logMessage), true)
    }
}
