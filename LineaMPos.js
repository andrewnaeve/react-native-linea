'use strict';
import {
	MPos
} from './NativeBridges';
import {
	NativeEventEmitter
} from 'react-native';

export default class LineaMPos {
	constructor() {
		this.evt = new NativeEventEmitter(MPos);
	}

	connect() {
		MPos.connect();
	}

	initializeEmv() {
		MPos.initEmv();
	}

	deinitializeEmv() {
		MPos.deinitEmv();
	}

	startTransaction() {
		MPos.startTransaction();
	}

	initRf() {
		MPos.initRf();
	}

	writeRf() {
		MPos.writeRf(amount);
	}

	addConnectionStateListener(callback) {
		return this.evt.addListener('connectionState', data => {
			callback(data);
		});
	}

	addTransactionFinishedListener(callback) {
		return this.evt.addListener('transactionFinished', data => {
			callback(data);
		});
	}

	addSmartCardInsertedListener(callback) {
		return this.evt.addListener('smartCardInserted', data => {
			callback(data);
		});
	}

	addRfCardDetectedListener(callback) {
		return this.evt.addListener('rfCardDetected', data => {
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

	addUiUpdateListener(callback) {
		return this.evt.addListener('uiUpdate', data => {
			console.log('debug:', data);
			callback(data);
		});
	}
}