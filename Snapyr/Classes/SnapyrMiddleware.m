//
//  SnapyrMiddleware.m
//  Analytics
//
//  Created by Tony Xiao on 9/19/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import "SnapyrUtils.h"
#import "SnapyrMiddleware.h"


@implementation SnapyrDestinationMiddleware
- (instancetype)initWithKey:(NSString *)integrationKey middleware:(NSArray<id<SnapyrMiddleware>> *)middleware
{
    if (self = [super init]) {
        _integrationKey = integrationKey;
        _middleware = middleware;
    }
    return self;
}
@end

@implementation SnapyrBlockMiddleware

- (instancetype)initWithBlock:(SnapyrMiddlewareBlock)block
{
    if (self = [super init]) {
        _block = block;
    }
    return self;
}

- (void)context:(SnapyrContext *)context next:(SnapyrMiddlewareNext)next
{
    self.block(context, next);
}

@end


@implementation SnapyrMiddlewareRunner

- (instancetype)initWithMiddleware:(NSArray<id<SnapyrMiddleware>> *_Nonnull)middlewares
{
    if (self = [super init]) {
        _middlewares = middlewares;
    }
    return self;
}

- (SnapyrContext *)run:(SnapyrContext *_Nonnull)context callback:(RunMiddlewaresCallback _Nullable)callback
{
    return [self runMiddlewares:self.middlewares context:context callback:callback];
}

// TODO: Maybe rename SnapyrContext to SnapyrEvent to be a bit more clear?
// We could also use some sanity check / other types of logging here.
- (SnapyrContext *)runMiddlewares:(NSArray<id<SnapyrMiddleware>> *_Nonnull)middlewares
                          context:(SnapyrContext *_Nonnull)context
                         callback:(RunMiddlewaresCallback _Nullable)callback
{
    __block SnapyrContext * _Nonnull result = context;

    BOOL earlyExit = context == nil;
    if (middlewares.count == 0 || earlyExit) {
        if (callback) {
            callback(earlyExit, middlewares);
        }
        return context;
    }
    
    [middlewares[0] context:result next:^(SnapyrContext *_Nullable newContext) {
        NSArray *remainingMiddlewares = [middlewares subarrayWithRange:NSMakeRange(1, middlewares.count - 1)];
        result = [self runMiddlewares:remainingMiddlewares context:newContext callback:callback];
    }];
    
    return result;
}

@end
