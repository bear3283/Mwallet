// 환율 중계.
//
// 앱이 환율 API 를 직접 부르면 두 가지가 걸린다.
//
//   1. 키가 앱에 실린다. IPA 를 열면 Info.plist 에서 그대로 꺼낼 수 있다.
//   2. 사용자마다 제 몫의 요청을 쓴다. 무료 요금제가 월 1,500건이면
//      사용자 스물다섯 명에서 앱이 멈춘다.
//
// 둘째가 먼저 온다. 그래서 이 중계의 본래 일은 캐시다 — 하루에 한 번만
// 위로 물어보고 나머지는 모두 그 답을 나눠 준다. 사용자가 몇이든 위로
// 가는 요청은 하루 한 번이다.
//
// 키는 Cloudflare 의 secret 으로 두어 코드에도 앱에도 실리지 않는다.

export default {
  async fetch(request, env, ctx) {
    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405 });
    }

    // 받는 길은 /latest/XXX 하나뿐이다. 열어 둔 만큼만 쓰이게 한다 —
    // 통째로 중계하면 남의 키로 남의 API 를 부르는 문이 된다.
    const url = new URL(request.url);
    const matched = url.pathname.match(/^\/latest\/([A-Z]{3})$/);
    if (!matched) {
      return new Response('Not found', { status: 404 });
    }
    const base = matched[1];

    const cache = caches.default;
    const cacheKey = new Request(`https://rates/latest/${base}`, { method: 'GET' });

    const cached = await cache.match(cacheKey);
    if (cached) return cached;

    const upstream = await fetch(
      `https://v6.exchangerate-api.com/v6/${env.EXCHANGERATE_API_KEY}/latest/${base}`
    );
    const body = await upstream.text();

    // 위가 실패하면 캐시하지 않는다. 오류 응답을 하루 동안 나눠 주면
    // 모든 사용자가 그날 내내 환율을 못 받는다.
    if (!upstream.ok) {
      return new Response(body, {
        status: upstream.status,
        headers: { 'content-type': 'application/json' },
      });
    }

    // API 가 알려 준 다음 갱신 시각까지만 담아 둔다. 그 시각이 지나면
    // 다음 요청 하나가 위로 올라가고, 나머지는 새 답을 나눠 받는다.
    let maxAge = 3600;
    try {
      const parsed = JSON.parse(body);
      if (parsed['time_next_update_unix']) {
        const seconds = parsed['time_next_update_unix'] - Math.floor(Date.now() / 1000);
        // 시계가 어긋나도 한 시간과 하루 사이를 벗어나지 않게 둔다.
        maxAge = Math.min(Math.max(seconds, 3600), 86400);
      }
    } catch (_) {
      // 해석하지 못해도 그대로 넘긴다. 읽는 것은 앱의 일이다.
    }

    const response = new Response(body, {
      headers: {
        'content-type': 'application/json',
        'cache-control': `public, max-age=${maxAge}`,
      },
    });

    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  },
};
