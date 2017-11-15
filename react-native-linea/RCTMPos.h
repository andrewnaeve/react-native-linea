//
//  react_native_linea.h
//  react-native-linea
//
//  Created by Andrew Naeve on 11-14-17.
//  Copyright © 2017 Andrew Naeve. All rights reserved.
//

#if __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#else
#import "RCTBridgeModule.h"
#import "RCTEventEmitter.h"
#endif

#import "DTDevices.h"

@interface RCTMPos : RCTEventEmitter <RCTBridgeModule, DTDeviceDelegate> {

DTDevices *linea;
BOOL isConnected;
BOOL rfidOn;

}

@end
