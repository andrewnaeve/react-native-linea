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

	initialize() {
		MPos.initEmv();
	}

	initSC() {
		MPos.initSmartCard();
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

	addSmartCardInsertedListener(callback) {
		return this.evt.addListener('emvTransactionStarted', data => {
			callback(data);
		});
	}

	addTransactionStartedListener(callback) {
		return this.evt.addListener('emvTransactionStarted', data => {
			callback(data);
		});
	}

	addDebugListener(callback) {
		return this.evt.addListener('debug', data => {
			console.log('debug:', data);
			callback(data);
		});
	}
}
