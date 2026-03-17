export function getUrlParams() {
	const params = {};
	const queryString = window.location.search;
	if (queryString) {
		const pairs = (queryString[0] === '?' ? queryString.substring(1) : queryString).split('&');
		for (let i = 0; i < pairs.length; i++) {
			const pair = pairs[i].split('=');
			params[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1] || '');
		}
	}
	return params;
}

export function getUrlParam(name, type) {
	const params = getUrlParams();
	if (params[name] == null) return null;
	if (type === 'number') return parseFloat(params[name]);
	if (type === 'int') return parseInt(params[name]);
	if (type === 'float') return parseFloat(params[name]);
	if (type === 'bool') return params[name] !== 'false';
	if (type === 'string') return params[name];
}

export function debouncePromise(fn, ms = 0) {
  let timeoutId: ReturnType<typeof setTimeout> | null = null;
  const pending = [];
  return (...args) => new Promise((res, rej) => {
		if (timeoutId != null) clearTimeout(timeoutId);
		timeoutId = setTimeout(() => {
			const currentPending = [...pending];
			pending.length = 0;
			Promise.resolve(fn.apply(this, args)).then(
				data => {
					currentPending.forEach(({ resolve }) => resolve(data));
				},
				error => {
					currentPending.forEach(({ reject }) => reject(error));
				}
			);
		}, ms);
		pending.push({ resolve: res, reject: rej });
	});
}

export const isIos = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

type NumberOptionSchema = {
	type: 'number';
	label: string;
	min?: number;
	max?: number;
	step?: number;
};

type BooleanOptionSchema = {
	type: 'boolean';
	label: string;
};

type ColorOptionSchema = {
	type: 'color';
	label: string;
};

type EnumOptionSchema = {
	type: 'enum';
	label: string;
	enum: {
		value: string | number | null;
		label: string;
	}[];
};

type RangeOptionSchema = {
	type: 'range';
	label: string;
	min: number;
	max: number;
	step?: number;
};

type ImageOptionSchema = {
	type: 'image';
	label: string;
};

type OptionsSchema = Record<string, NumberOptionSchema | BooleanOptionSchema | ColorOptionSchema | EnumOptionSchema | RangeOptionSchema | ImageOptionSchema>;

type GetOptionsSchemaValues<T extends OptionsSchema> = {
	[K in keyof T]:
	T[K] extends NumberOptionSchema ? number :
	T[K] extends BooleanOptionSchema ? boolean :
	T[K] extends ColorOptionSchema ? [number, number, number] :
	T[K] extends EnumOptionSchema ? T[K]['enum'][number]['value'] :
	T[K] extends RangeOptionSchema ? number :
	T[K] extends ImageOptionSchema ? string | null :
	never;
};

export type PlaygroundInstance<Options = any> = {
	render: (ctx: {
		time: number;
		commandEncoder: GPUCommandEncoder;
	}) => void;
	dispose?: () => void;
};

export type Playground<OpSc extends OptionsSchema = OptionsSchema> = {
	title: string;
	params: OpSc;
	getDefaultParams: () => GetOptionsSchemaValues<OpSc>;
	init: (args: {
		canvas: HTMLCanvasElement;
		width: number;
		height: number;
		wgpu: {
			device: GPUDevice;
			context: GPUCanvasContext;
			sampler: GPUSampler;
		};
		params: Readonly<GetOptionsSchemaValues<OpSc>>;
	}) => PlaygroundInstance<GetOptionsSchemaValues<OpSc>>;
};

export function definePlayground<const OpSc extends OptionsSchema>(def: Playground<OpSc>): Playground<OpSc> {
	return def;
}
