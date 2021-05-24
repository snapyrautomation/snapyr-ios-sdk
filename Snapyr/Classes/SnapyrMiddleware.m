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
    DLog(@"SnapyrMiddlewareRunner.run: running middlewares [%@]", self.middlewares);
    return [self runMiddlewares:self.middlewares context:context callback:callback];
}

- (SnapyrContext *)runMiddlewares:(NSArray<id<SnapyrMiddleware>> *_Nonnull)middlewares
                          context:(SnapyrContext *_Nonnull)context
                         callback:(RunMiddlewaresCallback _Nullable)callback
{
    __block SnapyrContext * _Nonnull result = context;
    DLog(@"SnapyrMiddlewareRunner.run: runMiddlwares");
    BOOL earlyExit = context == nil;
    if (middlewares.count == 0 || earlyExit) {
        if (callback) {
            callback(earlyExit, middlewares);
        }
        return context;
    }
    
    // OK -- this is the magic line, it calls the middleware, pasing it the next thing to call, which
    // includes a recursive call back to this function with the remaining middlewares
    // (holy crap - clear as mud)
    [middlewares[0] context:result next:^(SnapyrContext *_Nullable newContext) {
        NSArray *remainingMiddlewares = [middlewares subarrayWithRange:NSMakeRange(1, middlewares.count - 1)];
        result = [self runMiddlewares:remainingMiddlewares context:newContext callback:callback];
    }];
    
    return result;
}

@end
