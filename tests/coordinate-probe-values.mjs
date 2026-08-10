export const probeTolerance = 0.0001;

export const assertProbeValues = (name, actual, expected) => {
	for (let index = 0; index < expected.length; index += 1) {
		const actualValue = actual[index];
		const expectedValue = expected[index];
		if (!actualValue || !expectedValue || actualValue.some((value, component) => !Number.isFinite(value) || Math.abs(value - expectedValue[component]) > probeTolerance)) {
			throw new Error(`${name}: expected ${JSON.stringify(expectedValue)} at output ${index}, got ${JSON.stringify(actualValue)}`);
		}
	}
};
