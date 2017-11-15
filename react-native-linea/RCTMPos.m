#import "RCTMPos.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTEventEmitter.h>
#import "Config.h"

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
                @"debug"
            ];
}

- (void)sendConnectionState:(NSString *)state {
    [self sendEventWithName:@"connectionState" body:state];
}

- (void)connectionState:(int)state {
    switch (state) {
        case CONN_CONNECTED:
            isConnected = YES;
            [self sendConnectionState:@"connected"];
            break;
        case CONN_CONNECTING:
            isConnected = NO;
            [self sendConnectionState:@"connecting"];
            break;
        case CONN_DISCONNECTED:
            isConnected = NO;
            [self sendConnectionState:@"disconnected"];
            break;
    }
}

- (void)sendDebug:(NSString *)debug {
    [self sendEventWithName:@"debug" body:debug];
}

RCT_EXPORT_METHOD(connect) {
    linea = [DTDevices sharedDevice];
    [linea setDelegate:self];
    [linea connect];
}

RCT_EXPORT_METHOD(emv2Init) {
    NSError *error;
    linea = [DTDevices sharedDevice];
    [linea emv2Initialise:&error];
    if(error) {
        NSLog(@"Error you dumb: %@", error);
    }
    DTEMV2Info *info=[linea emv2GetInfo:nil];
    if(info) {
        bool universal=[linea getSupportedFeature:FEAT_EMVL2_KERNEL error:nil]&EMV_KERNEL_UNIVERSAL;
        bool lin = linea.deviceType==DEVICE_TYPE_LINEA;
        
        NSData * configContactless=[Config paymentGetConfigurationFromXML:lin]
    }
    
}



@end
