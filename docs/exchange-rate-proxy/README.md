# 환율 중계 세우기

앱이 환율 API 를 직접 부르지 않고 이 중계를 거치게 한다. 세우지 않아도
앱은 예전처럼 키로 직접 부르므로, 급하지 않다면 나중에 해도 된다.

## 왜 세우는가

**첫째는 규모다.** 지금은 사용자마다 제 몫의 요청을 쓴다.

| 사용자 | 한 달 요청 |
|---|---|
| 10명 | 600건 |
| 100명 | 6,000건 |
| 1,000명 | 60,000건 |

무료 요금제가 월 1,500건이면 **사용자 스물다섯 명쯤에서 앱이 멈춘다.**
중계가 하루치 답을 담아 두었다가 모두에게 나눠 주면, 사용자가 몇이든
위로 가는 요청은 **한 달 30건**이다.

**둘째는 키다.** 지금은 키가 `Info.plist` 에 실려 나가 IPA 를 열면 꺼낼 수
있다. 중계를 쓰면 키는 Cloudflare 안에만 있고 앱에는 주소만 실린다.

## 세워 둔 것

**이미 서 있다.** `https://mwallet-rates.bearwallet.workers.dev`

아래는 다시 세울 때의 순서다. Cloudflare 무료 요금제가 하루 10만 요청이라
이 앱에는 사실상 한도가 없는 셈이다.

```sh
npm install -g wrangler
wrangler login

cd docs/exchange-rate-proxy
wrangler deploy                            # 처음이면 workers.dev 하위 도메인을 묻는다
wrangler secret put EXCHANGERATE_API_KEY   # 지금 쓰는 키를 붙여 넣는다
```

배포하면 주소가 나온다. `https://mwallet-rates.<하위도메인>.workers.dev`

새 하위 도메인은 **인증서가 붙는 데 몇 분 걸린다.** 그 사이에 부르면
`curl` 이 TLS 실패로 끊긴다 — 잘못 세운 것이 아니니 기다렸다 다시 부른다.

## 앱에 연결하기

`Mwallet/View/Config.xcconfig` 에 주소를 적고 키는 비운다.

```
EXCHANGE_RATE_ENDPOINT = https:/$()/mwallet-rates.bearwallet.workers.dev
API_KEY =
```

`//` 를 `/$()/` 로 끊어 적는 것은 xcconfig 가 `//` 를 주석으로 보기 때문이다.

## 확인

```sh
curl -i https://mwallet-rates.bearwallet.workers.dev/latest/KRW
```

`conversion_rates` 가 담긴 JSON 이 오면 된다. 두 번째로 부르면
`cf-cache-status: HIT` 가 붙어 캐시가 도는 것을 볼 수 있다.

## 되돌리기

`EXCHANGE_RATE_ENDPOINT` 를 비우면 앱이 예전처럼 키로 직접 부른다.
중계가 죽어도 앱에 이미 받아 둔 환율 캐시가 남아 있어 그날은 버틴다.

## 열어 둔 길

`/latest/XXX` 하나뿐이다. 통째로 중계하면 남의 키로 남의 API 를 부르는
문이 되므로, 쓰는 만큼만 연다.
