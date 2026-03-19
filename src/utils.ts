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

export function throttlePromise(fn, ms = 0) {
	let lastExecuted = 0;
	let pendingPromise: Promise<any> | null = null;
	return (...args) => {
		const now = Date.now();
		if (pendingPromise) {
			return pendingPromise;
		}
		if (now - lastExecuted >= ms) {
			lastExecuted = now;
			return Promise.resolve(fn.apply(this, args));
		} else {
			pendingPromise = new Promise((res, rej) => {
				setTimeout(() => {
					lastExecuted = Date.now();
					pendingPromise = null;
					Promise.resolve(fn.apply(this, args)).then(res, rej);
				}, ms - (now - lastExecuted));
			});
			return pendingPromise;
		}
	};
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

type MediaOptionSchema = {
	type: 'media';
	label: string;
};

export type Media = {
	type: 'image';
	element: HTMLImageElement;
} | {
	type: 'video';
	element: HTMLVideoElement;
};

type OptionsSchema = Record<string, NumberOptionSchema | BooleanOptionSchema | ColorOptionSchema | EnumOptionSchema | RangeOptionSchema | MediaOptionSchema>;

type GetOptionsSchemaValues<T extends OptionsSchema> = {
	[K in keyof T]:
	T[K] extends NumberOptionSchema ? number :
	T[K] extends BooleanOptionSchema ? boolean :
	T[K] extends ColorOptionSchema ? [number, number, number] :
	T[K] extends EnumOptionSchema ? T[K]['enum'][number]['value'] :
	T[K] extends RangeOptionSchema ? number :
	T[K] extends MediaOptionSchema ? Media | null :
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
	}) => Promise<PlaygroundInstance<GetOptionsSchemaValues<OpSc>>>;
};

export function definePlayground<const OpSc extends OptionsSchema>(def: Playground<OpSc>): Playground<OpSc> {
	return def;
}

export function remap(value: number, fromMin: number, fromMax: number, toMin: number, toMax: number) {
	return toMin + (toMax - toMin) * ((value - fromMin) / (fromMax - fromMin));
}

export function setupWebcam() {
	return new Promise((resolve, reject) => {
		navigator.mediaDevices.getUserMedia({
			video: true,
			audio: false
		}).then(localMediaStream => {
			resolve(localMediaStream);
		}).catch(err => {
			if (err.name === 'PermissionDeniedError'){
				window.alert('denied permission');
			} else {
				window.alert(err.message);
			}

			reject(err);
		});
	});
}

export function getHex(c: [number, number, number]) {
	return `#${c.map(x => Math.round(x * 255).toString(16).padStart(2, '0')).join('')}`;
}

export function getRgb(hex: string | number): [number, number, number] | null {
	if (
		typeof hex === 'number' ||
		typeof hex !== 'string' ||
		!/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(hex)
	) {
		return null;
	}

	const m = hex.slice(1).match(/[0-9a-fA-F]{2}/g);
	if (m == null) return [0, 0, 0];
	return m.map(x => parseInt(x, 16) / 255) as [number, number, number];
}
