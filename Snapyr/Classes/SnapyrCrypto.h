//
//  SnapyrCrypto.h
//  Analytics
//
//  Copyright © 2016 Segment. All rights reserved.
//

@import Foundation;

@protocol SnapyrCrypto <NSObject>

- (NSData *_Nullable)encrypt:(NSData *_Nonnull)data;
- (NSData *_Nullable)decrypt:(NSData *_Nonnull)data;

@end
