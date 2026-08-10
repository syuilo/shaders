import assert from 'node:assert/strict';
import test from 'node:test';
import { assertProbeValues } from './coordinate-probe-values.mjs';

test('coordinate probe rejects non-finite readback components', () => {
	assert.throws(
		() => assertProbeValues('nan-shader', [[Number.NaN, 0.5625]], [[1, 0.5625]]),
		/nan-shader: expected \[1,0.5625\] at output 0, got \[null,0.5625\]/,
	);
	assert.throws(
		() => assertProbeValues('infinite-shader', [[Infinity, 0.5625]], [[1, 0.5625]]),
		/infinite-shader: expected \[1,0.5625\] at output 0, got \[null,0.5625\]/,
	);
});
