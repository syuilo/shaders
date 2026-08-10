import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { basename, join, relative } from 'node:path';
import test from 'node:test';

const multiply = ([x, y], [sx, sy]) => [x * sx, y * sy];
const divide = ([x, y], [sx, sy]) => [x / sx, y / sy];
const subtract = ([x, y], [dx, dy]) => [x - dx, y - dy];

const ambiguousCoordinateNames = new Set([
	'uv', '_uv', 'uv2', 'ndcUv', 'ndcVector', 'cellUv', 'modUv',
	'sourceUv', 'sampleUv', 'centerUv', 'transformedCoords', 'pos',
	'direction',
]);

const declarationKeywords = new Set(['const', 'let', 'override', 'var']);

function tokenizeWgsl(source) {
	const tokens = [];
	let offset = 0;
	let line = 1;

	while (offset < source.length) {
		if (/\s/.test(source[offset])) {
			if (source[offset] === '\n') line += 1;
			offset += 1;
			continue;
		}

		if (source.startsWith('//', offset)) {
			offset += 2;
			while (offset < source.length && source[offset] !== '\n') offset += 1;
			continue;
		}

		if (source.startsWith('/*', offset)) {
			let commentDepth = 1;
			offset += 2;
			while (offset < source.length && commentDepth > 0) {
				if (source.startsWith('/*', offset)) {
					commentDepth += 1;
					offset += 2;
				} else if (source.startsWith('*/', offset)) {
					commentDepth -= 1;
					offset += 2;
				} else {
					if (source[offset] === '\n') line += 1;
					offset += 1;
				}
			}
			continue;
		}

		const tokenOffset = offset;
		const tokenLine = line;
		let value;
		if (/[A-Za-z_]/.test(source[offset])) {
			offset += 1;
			while (offset < source.length && /[A-Za-z0-9_]/.test(source[offset])) offset += 1;
			value = source.slice(tokenOffset, offset);
		} else if (source.startsWith('->', offset)) {
			value = '->';
			offset += 2;
		} else {
			value = source[offset];
			offset += 1;
		}

		tokens.push({
			value,
			offset: tokenOffset,
			endOffset: offset,
			line: tokenLine,
			isIdentifier: /^[A-Za-z_][A-Za-z0-9_]*$/.test(value),
		});
	}

	return tokens;
}

function formatDeclaration(source, startOffset, endOffset) {
	return source.slice(startOffset, endOffset).replace(/\s+/g, ' ').trim();
}

function findClosingToken(tokens, openIndex, openValue, closeValue) {
	let depth = 0;
	for (let index = openIndex; index < tokens.length; index += 1) {
		if (tokens[index].value === openValue) depth += 1;
		if (tokens[index].value === closeValue) depth -= 1;
		if (depth === 0) return index;
	}
	return tokens.length - 1;
}

function findDeclarationHeader(tokens, startIndex, endIndex) {
	let nameIndex = startIndex;
	while (tokens[nameIndex]?.value === '@' && nameIndex < endIndex) {
		nameIndex += 2;
		if (tokens[nameIndex]?.value === '(') {
			nameIndex = findClosingToken(tokens, nameIndex, '(', ')') + 1;
		}
	}

	const nameToken = tokens[nameIndex];
	if (!nameToken?.isIdentifier || tokens[nameIndex + 1]?.value !== ':') return null;
	return { nameIndex, colonIndex: nameIndex + 1 };
}

function findDeclarationBoundary(tokens, typeStartIndex, closeIndex) {
	let groupingDepth = 0;
	for (let index = typeStartIndex; index < closeIndex; index += 1) {
		const value = tokens[index].value;
		if (['(', '[', '{'].includes(value)) groupingDepth += 1;
		if ([')', ']', '}'].includes(value)) groupingDepth -= 1;
		if (
			value === ','
			&& groupingDepth === 0
			&& findDeclarationHeader(tokens, index + 1, closeIndex)
		) return index;
	}
	return closeIndex;
}

function collectDeclarationList(source, tokens, openIndex, closeIndex) {
	const declarations = [];
	let declarationStartIndex = openIndex + 1;
	while (declarationStartIndex < closeIndex) {
		const header = findDeclarationHeader(tokens, declarationStartIndex, closeIndex);
		if (!header) break;

		const boundaryIndex = findDeclarationBoundary(tokens, header.colonIndex + 1, closeIndex);
		let endTokenIndex = boundaryIndex - 1;
		if (tokens[endTokenIndex].value === ',') endTokenIndex -= 1;
		const endToken = tokens[endTokenIndex];
		declarations.push({
			name: tokens[header.nameIndex].value,
			line: tokens[header.nameIndex].line,
			text: formatDeclaration(
				source,
				tokens[declarationStartIndex].offset,
				endToken.endOffset,
			),
		});
		declarationStartIndex = boundaryIndex + 1;
	}
	return declarations;
}

function collectNamedDeclarations(source) {
	const tokens = tokenizeWgsl(source);
	const declarations = [];

	for (let index = 0; index < tokens.length; index += 1) {
		const token = tokens[index];
		if (declarationKeywords.has(token.value)) {
			let nameIndex = index + 1;
			if (tokens[nameIndex]?.value === '<') {
				while (nameIndex < tokens.length && tokens[nameIndex].value !== '>') nameIndex += 1;
				nameIndex += 1;
			}
			const nameToken = tokens[nameIndex];
			if (!nameToken?.isIdentifier) continue;

			let endIndex = nameIndex;
			while (endIndex + 1 < tokens.length && tokens[endIndex + 1].value !== ';') {
				endIndex += 1;
			}
			if (tokens[endIndex + 1]?.value === ';') endIndex += 1;
			declarations.push({
				name: nameToken.value,
				line: nameToken.line,
				text: formatDeclaration(source, token.offset, tokens[endIndex].endOffset),
			});
			continue;
		}

		if (token.value !== 'fn' && token.value !== 'struct') continue;
		const openValue = token.value === 'fn' ? '(' : '{';
		const closeValue = token.value === 'fn' ? ')' : '}';
		const openIndex = tokens.findIndex((candidate, candidateIndex) => (
			candidateIndex > index && candidate.value === openValue
		));
		if (openIndex < 0) continue;
		const closeIndex = findClosingToken(tokens, openIndex, openValue, closeValue);
		declarations.push(...collectDeclarationList(source, tokens, openIndex, closeIndex));
		index = closeIndex;
	}

	return declarations;
}

function collectPublicShaderFiles(rootDirectory) {
	const shaderDirectory = join(rootDirectory, 'src', 'shaders');
	const shaderFiles = [];
	const visit = (directory) => {
		for (const entry of readdirSync(directory, { withFileTypes: true })) {
			const entryPath = join(directory, entry.name);
			if (entry.isDirectory()) visit(entryPath);
			if (entry.isFile() && basename(entryPath) === 'shader.wgsl') shaderFiles.push(entryPath);
		}
	};
	visit(shaderDirectory);
	return [join(rootDirectory, 'src', 'vertex.wgsl'), ...shaderFiles].sort();
}

function findAmbiguousCoordinateViolations(sources) {
	const violations = [];
	for (const { filePath, source } of sources) {
		for (const declaration of collectNamedDeclarations(source)) {
			if (!ambiguousCoordinateNames.has(declaration.name)) continue;
			violations.push(
				`${filePath.replaceAll('\\', '/')}:${declaration.line} ${declaration.text}`,
			);
		}
	}
	return violations;
}

test('naming audit ignores declarations inside nested block comments', () => {
	const source = `/* outer comment
/* nested comment */
let uv = vec2f(0.0);
*/
let sourceUv =
	vec2f(0.0);
`;

	assert.deepEqual(findAmbiguousCoordinateViolations([{
		filePath: 'fixtures/nested-comments.wgsl',
		source,
	}]), [
		'fixtures/nested-comments.wgsl:5 let sourceUv = vec2f(0.0);',
	]);
});

test('naming audit finds a parameter after a comparison-bearing generic parameter', () => {
	const source = `fn fixture(
	@location(0) safeCoordinate: array<i32, select(2, 3, A > B)>,
	@location(1) uv: array<vec2f, 4>,
) {}
`;

	assert.deepEqual(findAmbiguousCoordinateViolations([{
		filePath: 'fixtures/parameters.wgsl',
		source,
	}]), [
		'fixtures/parameters.wgsl:3 @location(1) uv: array<vec2f, 4>',
	]);
});

test('naming audit reports complete attributed struct field declarations', () => {
	const source = `struct Fixture {
	@location(0) pos: array<vec2f, 4>,
	@location(1) screenNdcUv: vec2f,
}
`;

	assert.deepEqual(findAmbiguousCoordinateViolations([{
		filePath: 'fixtures/struct-fields.wgsl',
		source,
	}]), [
		'fixtures/struct-fields.wgsl:2 @location(0) pos: array<vec2f, 4>',
	]);
});

test('naming audit handles var templates and multiline declarations', () => {
	const source = `@group(0) @binding(0)
var<storage, read_write> uv:
	array<vec2f>;

let sourceUv =
	vec2f(0.0);
`;

	assert.deepEqual(findAmbiguousCoordinateViolations([{
		filePath: 'fixtures/variables.wgsl',
		source,
	}]), [
		'fixtures/variables.wgsl:2 var<storage, read_write> uv: array<vec2f>;',
		'fixtures/variables.wgsl:5 let sourceUv = vec2f(0.0);',
	]);
});

test('naming audit rejects a bare direction vector name', () => {
	const source = `fn project(aspectUv: vec2f) -> f32 {
	let direction = normalize(aspectUv);
	return dot(aspectUv, direction);
}
`;

	assert.deepEqual(findAmbiguousCoordinateViolations([{
		filePath: 'fixtures/direction.wgsl',
		source,
	}]), [
		'fixtures/direction.wgsl:2 let direction = normalize(aspectUv);',
	]);
});

test('public shader coordinate declarations make their spaces apparent at use sites', () => {
	const rootDirectory = process.cwd();
	const sources = collectPublicShaderFiles(rootDirectory).map((filePath) => ({
		filePath: relative(rootDirectory, filePath),
		source: readFileSync(filePath, 'utf8'),
	}));
	const violations = findAmbiguousCoordinateViolations(sources);

	assert.deepEqual(
		violations,
		[],
		`coordinate-bearing values must name their coordinate space:\n${violations.join('\n')}`,
	);
});

test('aspect point helpers round-trip portrait, square, and landscape coordinates', () => {
	const cases = [
		{
			name: 'portrait',
			screenNdcUv: [0.5, -0.25],
			scale: [0.5625, 1],
			aspectUv: [0.28125, -0.25],
		},
		{
			name: 'square',
			screenNdcUv: [0.5, -0.25],
			scale: [1, 1],
			aspectUv: [0.5, -0.25],
		},
		{
			name: 'landscape',
			screenNdcUv: [0.5, -0.25],
			scale: [1, 0.5625],
			aspectUv: [0.5, -0.140625],
		},
	];

	for (const { name, screenNdcUv, scale, aspectUv } of cases) {
		assert.deepEqual(multiply(screenNdcUv, scale), aspectUv, `${name} forward point conversion`);
		assert.deepEqual(divide(aspectUv, scale), screenNdcUv, `${name} inverse point conversion`);
	}
});

test('aspect vector helpers round-trip portrait, square, and landscape displacements', () => {
	const cases = [
		{
			name: 'portrait',
			screenNdcVector: [-0.75, 0.5],
			scale: [0.5625, 1],
			aspectVector: [-0.421875, 0.5],
		},
		{
			name: 'square',
			screenNdcVector: [-0.75, 0.5],
			scale: [1, 1],
			aspectVector: [-0.75, 0.5],
		},
		{
			name: 'landscape',
			screenNdcVector: [-0.75, 0.5],
			scale: [1, 0.5625],
			aspectVector: [-0.75, 0.28125],
		},
	];

	for (const { name, screenNdcVector, scale, aspectVector } of cases) {
		assert.deepEqual(multiply(screenNdcVector, scale), aspectVector, `${name} forward vector conversion`);
		assert.deepEqual(divide(aspectVector, scale), screenNdcVector, `${name} inverse vector conversion`);
	}
});

test('cover maps a wider source by width and a narrower source by height', () => {
	assert.deepEqual(multiply([0.75, -0.5], [0.421875, 1]), [0.31640625, -0.5]);
	assert.deepEqual(multiply([0.75, -0.5], [1, 0.75]), [0.75, -0.375]);
});

test('contain maps a narrower source by width and a wider source by height', () => {
	assert.deepEqual(multiply([0.75, -0.5], [4 / 3, 1]), [1, -0.5]);
	assert.deepEqual(multiply([0.75, -0.5], [1, 64 / 27]), [0.75, -1.1851851851851851]);
});

test('source point deltas equal source-vector conversion', () => {
	const sourcePointA = multiply([0.75, -0.5], [0.421875, 1]);
	const sourcePointB = multiply([-0.25, 0.25], [0.421875, 1]);
	const sourcePointDelta = subtract(sourcePointA, sourcePointB);
	const sourceVector = multiply([1, -0.75], [0.421875, 1]);

	assert.deepEqual(sourcePointA, [0.31640625, -0.5]);
	assert.deepEqual(sourcePointB, [-0.10546875, 0.25]);
	assert.deepEqual(sourcePointDelta, [0.421875, -0.75]);
	assert.deepEqual(sourceVector, [0.421875, -0.75]);
});

test('2x2 adaptive samples keep the same offsets at differing global origins', () => {
	const offset = 0.015625;
	const samplesAtA = [
		[0.25 - offset, -0.5 - offset],
		[0.25 + offset, -0.5 - offset],
		[0.25 - offset, -0.5 + offset],
		[0.25 + offset, -0.5 + offset],
	];
	const samplesAtB = [
		[-0.75 - offset, 0.125 - offset],
		[-0.75 + offset, 0.125 - offset],
		[-0.75 - offset, 0.125 + offset],
		[-0.75 + offset, 0.125 + offset],
	];

	assert.deepEqual(samplesAtA, [
		[0.234375, -0.515625], [0.265625, -0.515625],
		[0.234375, -0.484375], [0.265625, -0.484375],
	]);
	assert.deepEqual(samplesAtB, [
		[-0.765625, 0.109375], [-0.734375, 0.109375],
		[-0.765625, 0.140625], [-0.734375, 0.140625],
	]);
	assert.deepEqual(samplesAtA.map((sample) => subtract(sample, [0.25, -0.5])), [
		[-0.015625, -0.015625], [0.015625, -0.015625],
		[-0.015625, 0.015625], [0.015625, 0.015625],
	]);
	assert.deepEqual(samplesAtB.map((sample) => subtract(sample, [-0.75, 0.125])), [
		[-0.015625, -0.015625], [0.015625, -0.015625],
		[-0.015625, 0.015625], [0.015625, 0.015625],
	]);
});

test('4x4 adaptive samples keep the same offsets at differing global origins', () => {
	const offset = 0.046875;
	const samplesAtA = [
		[0.25 - offset, -0.5 - offset],
		[0.25 + offset, -0.5 - offset],
		[0.25 - offset, -0.5 + offset],
		[0.25 + offset, -0.5 + offset],
	];
	const samplesAtB = [
		[-0.75 - offset, 0.125 - offset],
		[-0.75 + offset, 0.125 - offset],
		[-0.75 - offset, 0.125 + offset],
		[-0.75 + offset, 0.125 + offset],
	];

	assert.deepEqual(samplesAtA, [
		[0.203125, -0.546875], [0.296875, -0.546875],
		[0.203125, -0.453125], [0.296875, -0.453125],
	]);
	assert.deepEqual(samplesAtB, [
		[-0.796875, 0.078125], [-0.703125, 0.078125],
		[-0.796875, 0.171875], [-0.703125, 0.171875],
	]);
	assert.deepEqual(samplesAtA.map((sample) => subtract(sample, [0.25, -0.5])), [
		[-0.046875, -0.046875], [0.046875, -0.046875],
		[-0.046875, 0.046875], [0.046875, 0.046875],
	]);
	assert.deepEqual(samplesAtB.map((sample) => subtract(sample, [-0.75, 0.125])), [
		[-0.046875, -0.046875], [0.046875, -0.046875],
		[-0.046875, 0.046875], [0.046875, 0.046875],
	]);
});

test('zero liquid-paint displacement preserves the base aspect UV', () => {
	const baseAspectUv = [0.25, -0.5];
	const displacement = [0, 0];
	assert.deepEqual([
		baseAspectUv[0] + displacement[0],
		baseAspectUv[1] + displacement[1],
	], baseAspectUv);
});

test('cyber pointer shift treats trail components as aspect-independent cell ratios', () => {
	const pointerTrailScreenNdcVector = [0.4, -0.25];
	const aspectCellSize = [0.125, 0.25];
	const expectedSymbolShiftAspectVector = [-0.05, 0.0625];
	const aspectScales = {
		portrait: [0.5625, 1],
		square: [1, 1],
		landscape: [1, 0.5625],
	};

	for (const name of Object.keys(aspectScales)) {
		const symbolShiftAspectVector = multiply(
			pointerTrailScreenNdcVector.map((component) => -component),
			aspectCellSize,
		);
		assert.deepEqual(symbolShiftAspectVector, expectedSymbolShiftAspectVector, name);
	}

	assert.notDeepEqual(
		multiply(
			multiply(pointerTrailScreenNdcVector, aspectScales.portrait).map((component) => -component),
			aspectCellSize,
		),
		expectedSymbolShiftAspectVector,
		'geometric portrait conversion must not be applied to the effect control',
	);
	assert.notDeepEqual(
		multiply(
			multiply(pointerTrailScreenNdcVector, aspectScales.landscape).map((component) => -component),
			aspectCellSize,
		),
		expectedSymbolShiftAspectVector,
		'geometric landscape conversion must not be applied to the effect control',
	);
});

test('cyber symbols and background dots share the shifted cell-local aspect UV', () => {
	const cellLocalAspectUv = [0.0625, 0.125];
	const symbolShiftAspectVector = [-0.05, 0.0625];
	const shiftedCellLocalAspectUv = [
		cellLocalAspectUv[0] + symbolShiftAspectVector[0],
		cellLocalAspectUv[1] + symbolShiftAspectVector[1],
	];

	assert.deepEqual(shiftedCellLocalAspectUv, [0.012499999999999997, 0.1875]);

	const cyberShader = readFileSync('src/shaders/cyber/shader.wgsl', 'utf8');
	assert.equal(
		cyberShader.match(/distance\(shiftedCellLocalAspectUv \/ aspectCellSize/g)?.length,
		2,
		'both source and procedural background dots must use the shared shifted coordinate',
	);
});
