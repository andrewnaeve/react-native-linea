#import "RCTMPos.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTEventEmitter.h>
#import "Config.h"
#import "EMVTLV.h"
#import "crc32.h"
#import "EMVTags.h"
#import "EMVPrivateTags.h"

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
                @"emvTransactionStarted",
                @"smartCardInserted",
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

- (void)smartCardInserted:(SC_SLOTS)slot {
    [self sendEventWithName:@"smartCardInserted" body:@"smart card inserted: %@", slot];
}

- (void)emv2OnTransactionStarted {
    [self sendEventWithName:@"emvTransactionStarted" body:@"transaction started"];
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
RCT_EXPORT_METHOD(initEmv) {
    [self emv2Init];
}

RCT_EXPORT_METHOD(initSmartCard) {
    linea = [DTDevices sharedDevice];
    [linea setDelegate:self];
    [linea scInit:SLOT_MAIN error:nil];
    [linea scCardPowerOn:SLOT_MAIN error:nil];
}



#define RF_COMMAND(operation,c) {if(!c){displayAlert(@"Operation failed!", [NSString stringWithFormat:@"%@ failed, error %@, code: %d",operation,error.localizedDescription,(int)error.code]); return false;} }


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

 -(BOOL) emv2Init
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
           [linea emv2LoadContactlessConfiguration:configContactless configurationIndex:0 error:&error];
            //the idea here - load both "normal" configuration in slot 0 and in slot 1 load modified "always reject" config used for void/returns when you want to always decline just to get the data
            configContactless=[linea emv2CreatePANConfiguration:configContactless error:nil];
            [linea emv2LoadContactlessConfiguration:configContactless configurationIndex:1 error:nil];  //don't check for failure, in order to work on older firmwares
        }

    }
    return true;
 }

//  -(BOOL)emv2StartTransaction
//  {
//     NSError *error=nil;
//     //overwrite terminal capabilities flag depending on the connected device
//     NSData *initData=nil;
//     TLV *tag9f33=nil;
//     if([linea getSupportedFeature:FEAT_PIN_ENTRY error:nil]==FEAT_SUPPORTED)
//     {//pinpad
//         tag9f33=[TLV tlvWithHexString:@"60 B0 C8" tag:TAG_9F33_TERMINAL_CAPABILITIES];
//         //            tag9f33=[TLV tlvWithHexString:@"60 60 C8" tag:TAG_9F33_TERMINAL_CAPABILITIES];
//     }else
//     {//linea
//         tag9f33=[TLV tlvWithHexString:@"40 28 C8" tag:TAG_9F33_TERMINAL_CAPABILITIES];
//     }
//     TLV *tag9f66=[TLV tlvWithHexString:@"36 20 40 00" tag:0x9f66];

//     //enable cvv on manual card entry
//     TLV *tagCVVEnabled=[TLV tlvWithHexString:@"01" tag:TAG_C1_CVV_ENABLED];

//     //disable pan luhn check on manual entry
//     TLV *tagPANCheckDisabled=[TLV tlvWithHexString:@"01" tag:0xCA];

//     //change decimal separator to .
//     TLV *tagDecimalSeparator=[TLV tlvWithString:@" " tag:TAG_C2_DECIMAL_SEPARATOR];

//     tag9f33=[TLV tlvWithHexString:@"E0 10 C8" tag:TAG_9F33_TERMINAL_CAPABILITIES];

//     //enable application priority selection
//     TLV *tagC8=[TLV tlvWithHexString:@"01" tag:0xC8];

//     //enable apple VAS
//     TLV *tagCD=[TLV tlvWithHexString:@"01" tag:0xCD];

//     initData=[TLV encodeTags:@[tagCVVEnabled, tagDecimalSeparator, tagC8, tagCD, tagPANCheckDisabled]];

//     [linea emv2SetMessageForID:EMV_UI_ERROR_PROCESSING font:FONT_8X16 message:nil error:nil]; //disable transaction error

//     if([linea getSupportedFeature:FEAT_PIN_ENTRY error:nil]==FEAT_SUPPORTED)
//         [linea emv2SetPINOptions:PIN_ENTRY_DISABLED error:nil];
//     else
//         [linea emv2SetPINOptions:PIN_ENTRY_DISABLED error:nil];

//     //amount: $1.00, currency code: USD(840), according to ISO 4217
//     RF_COMMAND(@"EMV Init",[linea emv2SetTransactionType:0 amount:100 currencyCode:840 error:&error]);
//     //start the transaction, transaction steps will be notified via emv2On... delegate methods
//     RF_COMMAND(@"EMV Start Transaction",[linea emv2StartTransactionOnInterface:EMV_INTERFACE_CONTACT|EMV_INTERFACE_CONTACTLESS|EMV_INTERFACE_MAGNETIC|EMV_INTERFACE_MAGNETIC_MANUAL flags:0 initData:initData timeout:7*60 error:&error]);

//     return true;
// }


@end
