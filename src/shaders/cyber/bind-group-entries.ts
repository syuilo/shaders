export type CyberMainBindGroupResources = {
	uniformBuffer: GPUBuffer;
	sampler: GPUSampler;
	symbolTexturesView: GPUTextureView;
	sourceTextureView: GPUTextureView;
	pointerTrailBufferView: GPUTextureView;
	hasSource: boolean;
};

export const createCyberMainBindGroupEntries = (
	resources: CyberMainBindGroupResources,
): GPUBindGroupEntry[] => {
	const entries: GPUBindGroupEntry[] = [
		{ binding: 1, resource: { buffer: resources.uniformBuffer }},
		{ binding: 2, resource: resources.sampler },
		{ binding: 3, resource: resources.symbolTexturesView },
	];
	if (resources.hasSource) {
		entries.push({ binding: 4, resource: resources.sourceTextureView });
	}
	entries.push({ binding: 5, resource: resources.pointerTrailBufferView });
	return entries;
};
