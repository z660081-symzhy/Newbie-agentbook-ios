/* Agent 教材离线缓存：装一次，之后断网也能看 */
const CACHE = 'agentbook-3b75980c';
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
/* 策略：
   - 页面（导航 / document）：**网络优先**。联网时永远拿最新版本，只在断网时回退缓存。
     这一条很重要：以前是缓存优先，改版之后用户会被旧缓存卡住，
     看到的是老样式，而且怎么刷新都不变。
   - 其它静态资源（图标、manifest）：缓存优先，秒开。 */
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const isDoc = e.request.mode === 'navigate' || e.request.destination === 'document';
  e.respondWith((async () => {
    if (isDoc) {
      try {
        const fresh = await fetch(e.request);
        if (fresh && fresh.status === 200) {
          const copy = fresh.clone();
          caches.open(CACHE).then(c => c.put(e.request, copy)).catch(() => {});
        }
        return fresh;
      } catch (err) {
        const cached = await caches.match(e.request, { ignoreSearch: true });
        if (cached) return cached;
        const fallback = await caches.match('./index.html');
        if (fallback) return fallback;
        return new Response('离线且没有缓存', { status: 503 });
      }
    }
    const cached = await caches.match(e.request, { ignoreSearch: true });
    const network = fetch(e.request).then(resp => {
      if (resp && resp.status === 200) {
        const copy = resp.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy)).catch(() => {});
      }
      return resp;
    }).catch(() => null);
    if (cached) return cached;
    const fresh = await network;
    if (fresh) return fresh;
    return new Response('离线且没有缓存', { status: 503 });
  })());
});
