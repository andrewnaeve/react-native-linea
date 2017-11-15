'use strict';
import { MPos } from './NativeBridges';
import { NativeEventEmitter } from 'react-native';

export class LineaMPos {
	constructor() {
		this.evt = new NativeEventEmitter(Linea);
	}
	sayHi() {
		console.log('hey you');
	}
}
