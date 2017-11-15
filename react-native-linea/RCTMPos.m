#import "RCTMPos.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTEventEmitter.h>

@implementation RCTMPos

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

#pragma mark Events
- (NSArray<NSString *> *)supportedEvents {
    return @[
                @"connectionState",
                @"rfcardInfo",
                @"debug",
                @"magneticInfo",
                @"barcodeInfo"
            ];
}

@end