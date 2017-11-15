'use strict';
import { MPos } from './NativeBridges';
import { NativeEventEmitter } from 'react-native';

export default class LineaMPos {
	constructor() {
		this.evt = new NativeEventEmitter(MPos);
	}

	emvInit() {
		MPos.emv2Init();
	}
	sayHi() {
		console.log('hey you');
	}
}
