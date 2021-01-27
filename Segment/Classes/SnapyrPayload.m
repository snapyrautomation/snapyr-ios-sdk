#import "SnapyrPayload.h"
#import "SnapyrState.h"

@implementation SnapyrPayload

@synthesize userId = _userId;
@synthesize anonymousId = _anonymousId;

- (instancetype)initWithContext:(NSDictionary *)context integrations:(NSDictionary *)integrations
{
    if (self = [super init]) {
        // combine existing state with user supplied context.
        NSDictionary *internalContext = [SnapyrState sharedInstance].context.payload;
        
        NSMutableDictionary *combinedContext = [[NSMutableDictionary alloc] init];
        [combinedContext addEntriesFromDictionary:internalContext];
        [combinedContext addEntriesFromDictionary:context];

        _context = [combinedContext copy];
        _integrations = [integrations copy];
        _messageId = nil;
        _userId = nil;
        _anonymousId = nil;
    }
    return self;
}

@end


@implementation SEGApplicationLifecyclePayload
@end


@implementation SEGRemoteNotificationPayload
@end


@implementation SEGContinueUserActivityPayload
@end


@implementation SEGOpenURLPayload
@end
