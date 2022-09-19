#import "WKWebView+Custom.h"
//#import <WebKit/WebKit.h>
#import <objc/runtime.h> // Needed for method swizzling

typedef id (*deallocThing)(id Obj, SEL Sel);

static deallocThing old_dealloc = NULL;
static deallocThing old_alloc = NULL;

static void new_dealloc(id self, SEL _cmd);
static id new_alloc(id self, SEL _cmd);

@implementation WKWebView(Custom)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        Class wkClass = [WKWebView class];
        Class thisClass = [self class];
        bool oldAllocIsNull = (old_alloc == NULL);
        
        if ([self class] == [WKWebView class]) {
            Method originalDeallocMethod = class_getInstanceMethod([self class], NSSelectorFromString(@"dealloc"));
            IMP swizzleDeallocImp = (IMP)new_dealloc;
            old_dealloc = method_setImplementation(originalDeallocMethod, swizzleDeallocImp);
            
//            Method originalAllocMethod = class_getClassMethod([WKWebView class], NSSelectorFromString(@"alloc"));
//            IMP swizzleAllocImp = (IMP)new_alloc;
//            old_alloc = method_setImplementation(originalAllocMethod, swizzleAllocImp);
        }
    });
}

+ (id)alloc
{
    id newInst = [super alloc];
    NSLog(@"ALLOOOOOOOOOOOOOOOOOOOCOOCOOCOCOOCOCOCOCOCOCOCOCOCOCOCOCOC: %@", newInst);
    return newInst;
}

//- (void)dealloc
//{
//    NSLog(@"PAULPAULPAUL dealloc");
//
//}

//+ (id)alloc;
//{
//    NSLog(@"PAULPAULPAUL alloc");
//    Method originalMethod = class_getInstanceMethod([self class], NSSelectorFromString(@"alloc"));
//    IMP swizzleImp = (IMP)new_alloc;
//    old_alloc = method_setImplementation(originalMethod, swizzleImp);
//}
@end

static void new_dealloc(id self, SEL _cmd)
{
    // Call the original implementation, passing the same parameters
    // that this function was called with, including the selector.
    NSLog(@"DEALLOCOOOOOOOOOOOOOOOOOOCOOCOOCOCOOCOCOCOCOCOCOCOCOCOCOCOCOCOCOC: %@", self);
    
    old_dealloc(self, _cmd);
    
}

static id new_alloc(id self, SEL _cmd)
{
    // Call the original implementation, passing the same parameters
    // that this function was called with, including the selector.

    NSLog(@"alloc: %@", [self class]);
    NSLog(@"ALLOOOOOOOOOOOOOOOOOOOCOOCOOCOCOOCOCOCOCOCOCOCOCOCOCOCOCOCOCO: %@", self);
    
    return old_alloc(self, _cmd);
}

//@end
