'use strict';
import { MPos } from './NativeBridges';
import { NativeEventEmitter } from 'react-native';

export default class LineaMPos {
	constructor() {
		this.evt = new NativeEventEmitter(MPos);
	}

	connect() {
		MPos.connect();
	}

	emvInit() {
		MPos.emv2Init();
	}

	addConnectionStateListener(callback) {
		return this.evt.addListener('connectionState', data => {
			if (data === 'connected') {
				callback(true);
			} else {
				callback(false);
			}
		});
	}

	addDebugListener(callback) {
		return this.evt.addListener('debug', data => {
			console.log(data);
			callback(data);
		});
	}
}
