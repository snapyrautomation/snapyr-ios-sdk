//
//  StoreKitTrackerTest.swift
//  Analytics
//
//  Created by Tony Xiao on 9/20/16.
//  Copyright © 2016 Segment. All rights reserved.
//

import Snapyr
import XCTest

class mockTransaction: SKPaymentTransaction {
  override var transactionIdentifier: String? {
    return "tid"
  }
  override var transactionState: SKPaymentTransactionState {
    return SKPaymentTransactionState.purchased
  }
  override var payment: SKPayment {
    return mockPayment()
  }
}

class mockPayment: SKPayment {
  override var productIdentifier: String { return "pid" }
}

class mockProduct: SKProduct {
  override var productIdentifier: String { return "pid" }
  override var price: NSDecimalNumber { return 3 }
  override var localizedTitle: String { return "lt" }

}

class mockProductResponse: SKProductsResponse {
  override var products: [SKProduct] {
    return [mockProduct()]
  }
}

class StoreKitTrackerTests: XCTestCase {

    var test: TestMiddleware!
    var tracker: StoreKitTracker!
    var sdk: Snapyr!
    
    override func setUp() {
        super.setUp()        
        test = TestMiddleware()
        sdk = getUnitTestSDK(application:nil, sourceMiddleware: [test], destinationMiddleware: [])
        tracker = StoreKitTracker.trackTransactions(for: sdk)
    }
    
    func testSKPaymentQueueObserver() {
        let transaction = mockTransaction()
        XCTAssertEqual(transaction.transactionIdentifier, "tid")
        tracker.paymentQueue(SKPaymentQueue(), updatedTransactions: [transaction])
        
        tracker.productsRequest(SKProductsRequest(), didReceive: mockProductResponse())
        
        let payload = test.lastContext?.payload as? TrackPayload
        
        XCTAssertEqual(payload?.event, "Order Completed")
    }
}
