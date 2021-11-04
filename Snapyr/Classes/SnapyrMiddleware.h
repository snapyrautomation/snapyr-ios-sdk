//
//  SnapyrMiddleware.h
//  Analytics
//
//  Created by Tony Xiao on 9/19/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SnapyrContext.h"

typedef void (^SnapyrMiddlewareNext)(SnapyrContext *_Nullable newContext);

NS_SWIFT_NAME(Middleware)
@protocol SnapyrMiddleware
@required

// NOTE: If you want to hold onto references of context AFTER passing it through to the next
// middleware, you should explicitly create a copy via `[context copy]` to guarantee
// that it does not get changed from underneath you because contexts can be implemented
// as mutable objects under the hood for performance optimization.
// The behavior of keeping reference to a context AFTER passing it to the next middleware
// is strictly undefined.

// Middleware should **always** call `next`. If the intention is to explicitly filter out
// events from downstream, call `next` with `nil` as the param.
// It's ok to save next callback until a more convenient time, but it should always always be done.
// We'll probably actually add tests to sure it is so.
// TODO: Should we add error as second param to next?
- (void)context:(SnapyrContext *_Nonnull)context next:(SnapyrMiddlewareNext _Nonnull)next;

@end

typedef void (^SnapyrMiddlewareBlock)(SnapyrContext *_Nonnull context, SnapyrMiddlewareNext _Nonnull next);


NS_SWIFT_NAME(BlockMiddleware)
@interface SnapyrBlockMiddleware : NSObject <SnapyrMiddleware>

@property (nonnull, nonatomic, readonly) SnapyrMiddlewareBlock block;

- (instancetype _Nonnull)initWithBlock:(SnapyrMiddlewareBlock _Nonnull)block;

@end


typedef void (^RunMiddlewaresCallback)(BOOL earlyExit, NSArray<id<SnapyrMiddleware>> *_Nonnull remainingMiddlewares);

// XXX TODO: Add some tests for SnapyrMiddlewareRunner
NS_SWIFT_NAME(MiddlewareRunner)
@interface SnapyrMiddlewareRunner : NSObject

// While it is certainly technically possible to change middlewares dynamically on the fly. we're explicitly NOT
// gonna support that for now to keep things simple. If there is a real need later we'll see then.
@property (nonnull, nonatomic, readonly) NSArray<id<SnapyrMiddleware>> *middlewares;

- (SnapyrContext * _Nonnull)run:(SnapyrContext *_Nonnull)context callback:(RunMiddlewaresCallback _Nullable)callback;

- (instancetype _Nonnull)initWithMiddleware:(NSArray<id<SnapyrMiddleware>> *_Nonnull)middlewares;

@end

// Container object for middlewares for a specific destination.
NS_SWIFT_NAME(DestinationMiddleware)
@interface SnapyrDestinationMiddleware : NSObject
@property (nonatomic, strong, nonnull, readonly) NSString *integrationKey;
@property (nonatomic, strong, nullable, readonly) NSArray<id<SnapyrMiddleware>> *middleware;
- (instancetype _Nonnull)initWithKey:(NSString * _Nonnull)integrationKey middleware:(NSArray<id<SnapyrMiddleware>> * _Nonnull)middleware;
@end

NS_SWIFT_NAME(EdgeFunctionMiddleware)
@protocol SnapyrEdgeFunctionMiddleware
@required
@property (nonatomic, readonly, nullable) NSArray<id<SnapyrMiddleware>> *sourceMiddleware;
@property (nonatomic, readonly, nullable) NSArray<SnapyrDestinationMiddleware *> *destinationMiddleware;
- (void)setEdgeFunctionData:(NSDictionary *_Nullable)data;
- (void)addToDataBridge:(NSString * _Nonnull)key value:(id _Nonnull)value NS_SWIFT_NAME(addToDataBridge(key:value:));
- (void)removeFromDataBridge:(NSString * _Nonnull)key NS_SWIFT_NAME(removeFromDataBridge(key:));
- (NSDictionary<NSString *, id> * _Nullable)dataBridgeSnapshot;
@end

