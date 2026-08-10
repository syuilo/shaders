export type LiquidPaintBlurLightBindGroupResources = {
	commonUniformBuffer: GPUBuffer;
	blurUniformBuffer: GPUBuffer;
	sampler: GPUSampler;
	targetTextureView: GPUTextureView;
	blurRadiusTextureView: GPUTextureView;
};

export const createLiquidPaintBlurLightBindGroupEntries = (
	resources: LiquidPaintBlurLightBindGroupResources,
): GPUBindGroupEntry[] => [
	{ binding: 1, resource: { buffer: resources.commonUniformBuffer }},
	{ binding: 2, resource: { buffer: resources.blurUniformBuffer }},
	{ binding: 3, resource: resources.sampler },
	{ binding: 4, resource: resources.targetTextureView },
	{ binding: 5, resource: resources.blurRadiusTextureView },
];
