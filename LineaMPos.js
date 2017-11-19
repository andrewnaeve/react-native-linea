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

	startTransaction() {
		MPos.startTransaction();
	}

	addConnectionStateListener(callback) {
		return this.evt.addListener('connectionState', data => {
			callback(data);
		});
	}

	addSmartCardInsertedListener(callback) {
		return this.evt.addListener('smartCardInserted', data => {
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
