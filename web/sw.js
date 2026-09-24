/* Agent 教材离线缓存：装一次，之后断网也能看 */
const CACHE = 'agentbook-ecb4ac0c';
const ASSETS = ['./', './index.html', './manifest.webmanifest',
                './icon-180.png', './icon-192.png', './icon-512.png'];

self.addEventListener('install', e => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS).catch(() => c.add('./index.html'))));
});

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});

/* 策略：先用缓存秒开（离线优先），同时后台悄悄拉一次最新版本写回缓存。
   这样既能离线用，联网时又会自动更新到最新版，不用手动清缓存。 */
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith((async () => {
    const cached = await caches.match(e.request, { ignoreSearch: true });
    const network = fetch(e.request).then(resp => {
      if (resp && resp.status === 200) {
        const copy = resp.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy)).catch(() => {});
      }
      return resp;
    }).catch(() => null);
    if (cached) return cached;                       // 有缓存：立刻给，不等网络
    const fresh = await network;
    if (fresh) return fresh;
    const fallback = await caches.match('./index.html');
    if (fallback) return fallback;
    return new Response('离线且没有缓存', { status: 503 });
  })());
});
