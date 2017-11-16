#import "RCTMPos.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTEventEmitter.h>
#import "Config.h"
#import "EMVTLV.h"
#import "crc32.h"

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

static uint32_t calculateConfigurationChecksum(NSData *config)
{
    NSArray<TLV *> *tags=[TLV decodeTags:config];

    CC_CRC32_CTX crc;
    CC_CRC32_Init(&crc);

    for (TLV *t in tags) {
        if(t.tag!=0xE4)
        {
            CC_CRC32_Update(&crc, t.bytes, t.data.length);
        }
    }

    uint8_t r[4];

    CC_CRC32_Final(r, &crc);

    return crc.crc;
}

static int getConfigurationVesrsion(NSData *configuration)
{
    NSArray *arr=[TLV decodeTags:configuration];
    if(!arr)
        return 0;
    for (TLV *tag in arr)
    {
        if(tag.tag==0xE4)
        {
            TLV *cfgtag=[TLV findLastTag:0xC1 tags:[TLV decodeTags:tag.data]];
            
            const uint8_t *data=cfgtag.data.bytes;
            int ver=(data[0]<<24)|(data[1]<<16)|(data[2]<<8)|(data[3]<<0);

            if(ver==0)
                ver=calculateConfigurationChecksum(configuration);

            return ver;
        }
    }
    return 0;
}

 -(bool) initEmv
 {
     // universal = false, linea = true;
    NSError *error=nil;
    linea = [DTDevices sharedDevice];
    DTEMV2Info *info=[linea emv2GetInfo:nil];

    if (info) {
        // bool universal=[linea getSupportedFeature:FEAT_EMVL2_KERNEL error:nil]&EMV_KERNEL_UNIVERSAL;
        // bool lin = linea.deviceType==DEVICE_TYPE_LINEA;
        NSData *configContactless=[Config paymentGetConfigurationFromXML:@"contactless_linea.xml"];
        if(info.contactlessConfigurationVersion!=getConfigurationVesrsion(configContactless))
        {
            RF_COMMAND(@"EMV Load Contactless Configuration",[linea emv2LoadContactlessConfiguration:configContactless configurationIndex:0 error:&error]);
            //the idea here - load both "normal" configuration in slot 0 and in slot 1 load modified "always reject" config used for void/returns when you want to always decline just to get the data
            configContactless=[linea emv2CreatePANConfiguration:configContactless error:nil];
            [linea emv2LoadContactlessConfiguration:configContactless configurationIndex:1 error:nil];  //don't check for failure, in order to work on older firmwares
        }

    }
    return true;
 }

@end
