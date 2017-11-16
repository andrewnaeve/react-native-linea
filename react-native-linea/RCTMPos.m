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

 // Events

- (void)sendConnectionState:(NSString *)state {
    [self sendEventWithName:@"connectionState" body:state];
}

- (void)sendDebug:(NSString *)debug {
    [self sendEventWithName:@"debug" body:debug];
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


RCT_EXPORT_METHOD(connect) {
    linea = [DTDevices sharedDevice];
    [linea setDelegate:self];
    [linea connect];
}

 // EMV2 Init

 void displayAlert(NSString *title, NSString *message)
 {
     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
     [alert show];
 }

 #define RF_COMMAND(operation,c) {if(!c){displayAlert(@"Operation failed!", [NSString stringWithFormat:@"%@ failed, error %@, code: %d",operation,error.localizedDescription,(int)error.code]); return false;} }

RCT_EXPORT_METHOD(emv2Init) {
    [self initEmv];
}

 -(void) initEmv
 {
     // universal = false, linea = true;
    NSError *error=nil;
    linea = [DTDevices sharedDevice];
    DTEMV2Info *info=[linea emv2GetInfo:nil];
    [self sendDebug:info];

    if (info) {
    bool universal=[linea getSupportedFeature:FEAT_EMVL2_KERNEL error:nil]&EMV_KERNEL_UNIVERSAL;
    bool lin = linea.deviceType==DEVICE_TYPE_LINEA;


    NSData *configContactless=[Config paymentGetConfigurationFromXML:@"contactless_linea.xml"];

    if(info.contactlessConfigurationVersion!=getConfigurationVesrsion(configContactless))
    {
        RF_COMMAND(@"EMV Load Contactless Configuration",[dtdev emv2LoadContactlessConfiguration:configContactless configurationIndex:0 error:&error]);
        //the idea here - load both "normal" configuration in slot 0 and in slot 1 load modified "always reject" config used for void/returns when you want to always decline just to get the data
        configContactless=[dtdev emv2CreatePANConfiguration:configContactless error:nil];
        [dtdev emv2LoadContactlessConfiguration:configContactless configurationIndex:1 error:nil];  //don't check for failure, in order to work on older firmwares
    }

    }


    
 }

@end
