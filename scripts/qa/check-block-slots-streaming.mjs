#!/usr/bin/env node
// The block slot check for a document that is still streaming: the same
// overlap and partial-syntax rules, but a screen without a replaced block yet
// passes, since the stream may not have reached the first one.
import { checkDevices } from './check-block-slots.mjs';

checkDevices({ allowEmpty: true });
