static int nRFCards=0;
static int nRFCardSuccess=0;

#import <CommonCrypto/CommonDigest.h>
#import "RCTMPos.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTEventEmitter.h>
#import "Config.h"
#import "EMVTLV.h"
#import "crc32.h"
#import "EMVTags.h"
#import "EMVPrivateTags.h"
#import "dukpt.h"
#import "EMVProcessorHelper.h"

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

- (void)emv2OnTransactionStarted {
    [self sendEventWithName:@"emvTransactionStarted" body:@"transaction started"];
}

- (void)smartCardInserted:(SC_SLOTS)slot {
    [self sendEventWithName:@"smartCardInserted" body:@"smart card inserted"];
}

-(void)emv2OnUserInterfaceCode:(int)code status:(int)status holdTime:(NSTimeInterval)holdTime {
    [self sendEventWithName:@"debug" body:@"ui update"];
}

-(void)emv2OnOnlineProcessing:(NSData *)data {
    [self encryptedTagsDemo];
    //called when the kernel wants an approval online from the server, encapsulate the server response tags
    //in tag 0xE6 and set the server communication success or fail in tag C2
    
    //for the demo fake a successful server response (30 30)
    NSData *serverResponse=[TLV encodeTags:@[[TLV tlvWithHexString:@"30 30" tag:TAG_8A_AUTH_RESP_CODE]]];
    NSData *response=[TLV encodeTags:@[[TLV tlvWithHexString:@"01" tag:0xC2],[TLV tlvWithData:serverResponse tag:0xE6]]];
    [linea emv2SetOnlineResult:response error:nil];

    [self sendEventWithName:@"debug" body:@"on online processing"];
}

-(void)emv2OnApplicationSelection:(NSData *)applicationTags {
    [self sendEventWithName:@"debug" body:@"select application"];
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
    linea = [DTDevices sharedDevice];
    [linea setDelegate:self];
    [self emv2Init];
    [linea scInit:SLOT_MAIN error:nil];
    [linea scCardPowerOn:SLOT_MAIN error:nil];
}

RCT_EXPORT_METHOD(startTransaction) {
    [self emv2StartTransaction];
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
    [linea emv2Initialise:&error];
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

 -(BOOL)emv2StartTransaction
 {
    NSError *error=nil;
    //overwrite terminal capabilities flag depending on the connected device
    NSData *initData=nil;
    TLV *tag9f33=nil;
    if([linea getSupportedFeature:FEAT_PIN_ENTRY error:nil]==FEAT_SUPPORTED)
    {//pinpad
        tag9f33=[TLV tlvWithHexString:@"60 B0 C8" tag:TAG_9F33_TERMINAL_CAPABILITIES];
        //            tag9f33=[TLV tlvWithHexString:@"60 60 C8" tag:TAG_9F33_TERMINAL_CAPABILITIES];
    }else
    {//linea
        tag9f33=[TLV tlvWithHexString:@"40 28 C8" tag:TAG_9F33_TERMINAL_CAPABILITIES];
    }
    TLV *tag9f66=[TLV tlvWithHexString:@"36 20 40 00" tag:0x9f66];

    //enable cvv on manual card entry
    TLV *tagCVVEnabled=[TLV tlvWithHexString:@"01" tag:TAG_C1_CVV_ENABLED];

    //disable pan luhn check on manual entry
    TLV *tagPANCheckDisabled=[TLV tlvWithHexString:@"01" tag:0xCA];

    //change decimal separator to .
    TLV *tagDecimalSeparator=[TLV tlvWithString:@" " tag:TAG_C2_DECIMAL_SEPARATOR];

    tag9f33=[TLV tlvWithHexString:@"E0 10 C8" tag:TAG_9F33_TERMINAL_CAPABILITIES];

    //enable application priority selection
    TLV *tagC8=[TLV tlvWithHexString:@"01" tag:0xC8];

    //enable apple VAS
    TLV *tagCD=[TLV tlvWithHexString:@"01" tag:0xCD];

    initData=[TLV encodeTags:@[tagCVVEnabled, tagDecimalSeparator, tagC8, tagCD, tagPANCheckDisabled]];

    [linea emv2SetMessageForID:EMV_UI_ERROR_PROCESSING font:FONT_8X16 message:nil error:nil]; //disable transaction error

    if([linea getSupportedFeature:FEAT_PIN_ENTRY error:nil]==FEAT_SUPPORTED)
        [linea emv2SetPINOptions:PIN_ENTRY_DISABLED error:nil];
    else
        [linea emv2SetPINOptions:PIN_ENTRY_DISABLED error:nil];

    //amount: $1.00, currency code: USD(840), according to ISO 4217
    [linea emv2SetTransactionType:0 amount:100 currencyCode:840 error:&error];
    //start the transaction, transaction steps will be notified via emv2On... delegate methods
    [linea emv2StartTransactionOnInterface:EMV_INTERFACE_CONTACT flags:0 initData:initData timeout:7*60 error:&error];

    return true;
}

-(void)emv2OnTransactionFinished:(NSData *)data;
{
    
    NSLog(@"emv2OnTransactionFinished: %@",data);
    
    //try to get some encrypted tags and decrypt them
    [self encryptedTagsDemo];
    
    
    if(!data)
    {
        [linea emv2Deinitialise:nil];
        [self sendEventWithName:@"debug" body:@"Transaction could not be completed"];
        return;
    }
    
    //emv2OnTransactionFinished is used to get the final response from the transaction in non-emulation mode
    //data is extracted from the returned tags or manually asked for before calling emv2Deinitialise
    
    //parse data to display, send the rest to server
    
    //find and get Track1 masked and Track2 masked tags for display purposes
    NSString *t1Masked=nil;
    NSString *t2Masked=nil;
    
    NSArray *tags=[TLV decodeTags:data];
    // logView.text=[NSString stringWithFormat:@"Final tags:\n%@",tags];
    
    TLV *t;
    
    NSMutableString *receipt=[NSMutableString string];
    NSLog(@"Tags: %@",tags);
    
    [receipt appendFormat:@"* Datecs Ltd *\n"];
    [receipt appendFormat:@"\n"];
    
    
    [receipt appendFormat:@"Terminal ID: %@\n",[EMVProcessorHelper decodeNib:[TLV findLastTag:TAG_9F1C_TERMINAL_ID tags:tags].data]];
    [receipt appendFormat:@"\n"];
    
    [receipt appendFormat:@"Date: %@ %@\n",
     [EMVProcessorHelper decodeDateString:[TLV findLastTag:TAG_9A_TRANSACTION_DATE tags:tags].data],
     [EMVProcessorHelper decodeTimeString:[TLV findLastTag:TAG_9F21_TRANSACTION_TIME tags:tags].data]
     ];
    //    [receipt appendFormat:@"Transaction Sequence: %d\n",[EMVProcessorHelper decodeInt:[TLV findLastTag:TAG_9F41_TRANSACTION_SEQ_COUNTER tags:tags].data]];
    //    [receipt appendFormat:@"\n"];
    //
    //    if([cardInfo valueForKey:@"cardholderName"])
    //        [receipt appendFormat:@"Name: %@\n",[cardInfo valueForKey:@"cardholderName"]];
    //    if([cardInfo valueForKey:@"accountNumber"])
    //        [receipt appendFormat:@"PAN: %@\n",[cardInfo valueForKey:@"accountNumber"]];
    //    if([TLV findLastTag:TAG_5F34_PAN_SEQUENCE_NUMBER tags:tags])
    //    {
    //        [receipt appendFormat:@"PAN-SEQ: %@\n",[EMVProcessorHelper decodeNib:[TLV findLastTag:TAG_5F34_PAN_SEQUENCE_NUMBER tags:tags].data]];
    //    }
    //    [receipt appendFormat:@"AID: %@\n",[EMVProcessorHelper decodeHexString:[TLV findLastTag:TAG_84_DF_NAME tags:tags].data]];
    //    [receipt appendFormat:@"\n"];
    
    [receipt appendFormat:@"* Payment *\n"];
    
    
    int transactionResult=[EMVProcessorHelper decodeInt:[TLV findLastTag:TAG_C1_TRANSACTION_RESULT tags:tags].data];
    
    nRFCards++;
    NSString *transactionResultString=nil;
    switch (transactionResult)
    {
        case EMV_RESULT_APPROVED:
            transactionResultString=@"APPROVED";
            nRFCardSuccess++;
            break;
        case EMV_RESULT_DECLINED:
            nRFCardSuccess++;
            transactionResultString=@"DECLINED";
            break;
        case EMV_RESULT_TRY_ANOTHER_INTERFACE:
            transactionResultString=@"TRY ANOTHER INTERFACE";
            break;
        case EMV_RESULT_TRY_AGAIN:
            transactionResultString=@"TRY AGAIN";
            break;
        case EMV_RESULT_END_APPLICATION:
            transactionResultString=@"END APPLICATION";
            break;
    }
    [receipt appendFormat:@"Transaction Result:\n"];
    [receipt appendFormat:@"%@\n",transactionResultString];
    [receipt appendFormat:@"\n"];


    t=[TLV findLastTag:TAG_C3_TRANSACTION_INTERFACE tags:tags];
    if(t)
    {
        const uint8_t *bytes=t.data.bytes;
        switch (bytes[0]) {
            case EMV_INTERFACE_CONTACT:
                [receipt appendString:@"Interface: contact\n"];
                break;
            case EMV_INTERFACE_CONTACTLESS:
                [receipt appendString:@"Interface: contactless\n"];
                break;
            case EMV_INTERFACE_MAGNETIC:
                [receipt appendString:@"Interface: magnetic\n"];
                break;
            case EMV_INTERFACE_MAGNETIC_MANUAL:
                [receipt appendString:@"Interface: manual entry\n"];
                break;
        }
    }

    t=[TLV findLastTag:TAG_C5_TRANSACTION_INFO tags:tags];
    if(t)
    {
        [receipt appendFormat:@"CL Card Scheme: %d\n",t.bytes[0]];
        [receipt appendFormat:@"Transaction Type: %@\n",((t.bytes[1]&EMV_CL_TRANS_TYPE_MSD)?@"MSD":@"EMV")];
    }

    NSData *trackData=[linea emv2GetCardTracksEncryptedWithFormat:ALG_TRANSARMOR_DUKPT keyID:0 error:nil];
    if(trackData)
        [receipt appendFormat:@"Encrypted track data: %@\n",trackData];
    
    if(transactionResult==EMV_RESULT_APPROVED)
    {
        t=[TLV findLastTag:TAG_D3_TRACK1_MASKED tags:tags];
        if(t)
            t1Masked=[[NSString alloc] initWithData:t.data encoding:NSASCIIStringEncoding];
        t=[TLV findLastTag:TAG_D4_TRACK2_MASKED tags:tags];
        if(t)
            t2Masked=[[NSString alloc] initWithData:t.data encoding:NSASCIIStringEncoding];
        
        NSDictionary *card=[linea msProcessFinancialCard:t1Masked track2:t2Masked];
        if(card)
        {
            if([card valueForKey:@"cardholderName"])
                [receipt appendFormat:@"Name: %@\n",[card valueForKey:@"cardholderName"]];
            if([card valueForKey:@"accountNumber"])
                [receipt appendFormat:@"Number: %@\n",[card valueForKey:@"accountNumber"]];
            
            if([card valueForKey:@"expirationMonth"])
                [receipt appendFormat:@"Expiration: %@/%@\n",[card valueForKey:@"expirationMonth"],[card valueForKey:@"expirationYear"]];
            [receipt appendString:@"\n"];
        }
        
        //try to get some encrypted tags and decrypt them
        [self encryptedTagsDemo];
    
        //    [receipt appendFormat:@"TVR: %@\n",[EMVProcessorHelper decodeHexString:[TLV findLastTag:TAG_95_TVR tags:tags].data]];
        //    [receipt appendFormat:@"TSI: %@\n",[EMVProcessorHelper decodeHexString:[TLV findLastTag:TAG_9B_TSI tags:tags].data]];
        //    [receipt appendFormat:@"\n"];
        //
        //    NSString *issuerScriptResults=[EMVProcessorHelper decodeHexString:[TLV findLastTag:TAG_C8_ISSUER_SCRIPT_RESULTS tags:tags].data];
        //    if(issuerScriptResults)
        //        [receipt appendFormat:@"%@\n",issuerScriptResults];
        
        if([dtdev getSupportedFeature:FEAT_PRINTING error:nil])
        {
            [linea prnPrintText:@"{+B}{=C}TRANSACTION COMPLETE" error:nil];
            [linea prnPrintText:receipt error:nil];
            [linea prnFeedPaper:0 error:nil];
        }
        
        [receipt insertString:[NSString stringWithFormat:@"nEMVCards: %d, success: %d, failed: %d\n",nRFCards,nRFCardSuccess,nRFCards-nRFCardSuccess] atIndex:0];
        
        
        displayAlert(@"Transaction complete!", receipt);
    }else
    {
        NSString *reasonMessage=@"Terminal declined";
        t=[TLV findLastTag:TAG_C4_TRANSACTION_FAILED_REASON tags:tags];
        if(t)
        {
            const uint8_t *bytes=t.data.bytes;
            int reason=bytes[0];
            if(reason==REASON_CANCELED)
                reasonMessage=@"User cancelled";
            if(reason==REASON_TIMEOUT)
                reasonMessage=@"Transaction timed out";
        }
        displayAlert(@"Transaction failed!", reasonMessage);
    }
}

-(void)encryptedTagsDemo
{
    NSError *error;
    
    NSData *tagList = [TLV encodeTagList:@[
                                           [NSNumber numberWithInt:0x56], //track1
                                           [NSNumber numberWithInt:0x57], //track2
                                           [NSNumber numberWithInt:0x5A], //pan
                                           [NSNumber numberWithInt:0x5F24], //expiration date
                                           [NSNumber numberWithInt:0x5F20], //account name
                                           ]];
    
    //get the tags encrypted with 3DES CBC and key loaded at positon 2
    NSData *packetData=[linea emv2GetTagsEncrypted:tagList format:TAGS_FORMAT_DATECS keyType:KEY_TYPE_3DES_CBC keyIndex:2 packetID:0x12345678 error:&error];
//    packetData=[dtdev emv2GetTagsPlain:tagList error:nil];
    if(!packetData || packetData.length==0)
        return; //no data
    const uint8_t *packet=packetData.bytes;
    
    int index=0;
    int format = (packet[index + 0] << 24) | (packet[index + 1] << 16) | (packet[index + 2] << 8) | (packet[index + 3]);
    if(format!=TAGS_FORMAT_DATECS)
        return; //wrong format
    index += 4;
    
    //try to decrypt the packet
    NSData *encrypted=[NSData dataWithBytes:&packet[index] length:packetData.length-index];
    
    static uint8_t tridesKey[16]={0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10};
//    uint8_t tridesKey[16]={0x31,0x31,0x31,0x31,0x31,0x31,0x31,0x31,0x31,0x31,0x31,0x31,0x31,0x31,0x31,0x31};

    uint8_t decrypted[1024];
    trides_crypto(kCCDecrypt,0,encrypted.bytes,encrypted.length,decrypted,tridesKey);

    
    //parse and verify the data
    index = 0;
    
    format = (decrypted[index + 0] << 24) | (decrypted[index + 1] << 16) | (decrypted[index + 2] << 8) | (decrypted[index + 3]);
    index += 4;
    
    int dataLen = (decrypted[index + 0] << 8) | (decrypted[index + 1]) - 4 - 4 - 16;
    if(dataLen<0 || dataLen>encrypted.length)
        return; //invalid length
    index += 2;
    int hashStart = index;
    
    int packetID = (decrypted[index + 0] << 24) | (decrypted[index + 1] << 16) | (decrypted[index + 2] << 8) | (decrypted[index + 3]);
    index += 4;
    
    index += 4;
    
    NSData *sn=[NSData dataWithBytes:&decrypted[index] length:16];
    index += sn.length;
    
    NSData *tags=[NSData dataWithBytes:&decrypted[index] length:dataLen];
    index += tags.length;
    int hashEnd = index;
  
    NSData *hashPacket=[NSData dataWithBytes:&decrypted[index] length:32];
    index += hashPacket.length;
    
    uint8_t hash[32];
    CC_SHA256(&decrypted[hashStart],hashEnd-hashStart,hash);
    index+=CC_SHA256_DIGEST_LENGTH;
    
    NSData *hashComputed=[NSData dataWithBytes:hash length:sizeof(hash)];
    
    if(![hashPacket isEqualToData:hashComputed])
        return; //invalid packet checksum
    
    //everything is valid, parse the tags now
    NSLog(@"TLV: %@",tags);
    NSArray *t=[TLV decodeTags:tags];
    NSLog(@"Tags: %@",t);
}



@end
