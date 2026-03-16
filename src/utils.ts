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
