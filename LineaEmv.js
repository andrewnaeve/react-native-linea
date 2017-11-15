'use strict';
import { LineaEmv } from './NativeBridges';
import { NativeEventEmitter } from 'react-native';

export default class LineaEmv {
	constructor() {
		this.evt = new NativeEventEmitter(Linea);
	}
}
