const MIN_BLUR_SAMPLES = 4;
const MAX_BLUR_SAMPLES = 16;
const MIN_MONTE_CARLO_SAMPLES = 1;
const MAX_MONTE_CARLO_SAMPLES = 512;

type BlurMethod = 'standardMip' | 'standard' | 'monteCarlo' | 'twoPass';

export function getBlurSampleCount(quality: number, method: Exclude<BlurMethod, 'twoPass'>): number {
	const normalizedQuality = Number.isFinite(quality) ? Math.min(Math.max(quality, 0), 1) : 0;
	const minSamples = method === 'standardMip' ? MIN_BLUR_SAMPLES : MIN_MONTE_CARLO_SAMPLES;
	const maxSamples = method === 'standardMip' ? MAX_BLUR_SAMPLES : MAX_MONTE_CARLO_SAMPLES;
	return Math.round(minSamples + normalizedQuality * (maxSamples - minSamples));
}

export function getMipLevelCount(width: number, height: number): number {
	return 1 + Math.floor(Math.log2(Math.max(width, height)));
}

export function shouldGenerateBlurMipmaps(blurStrength: number, method: BlurMethod): boolean {
	return blurStrength > 0 && method === 'standardMip';
}
