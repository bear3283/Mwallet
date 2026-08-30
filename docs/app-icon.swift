// Mwallet 앱 아이콘 1024×1024 를 그린다.
//
// 지갑 한 장과 그 앞의 M. Mission wallet 의 M 이다.
//
// ─────────────────────────────────────────────────────────────
// 무엇을 바꿨나
//
// 예전에는 W 하나가 아이콘을 가득 채웠다(Wallet 의 W). 뜻이 글자에만
// 있어서 아이콘 어디에도 지갑이 없었고, 그래서 V 이음선과 실밥으로
// 지갑을 흉내 내 봤지만 획 위에 얹는 장식에서 더 나아가지 못했다.
//
// 지갑을 그리기로 했다. 몸통과 주머니, 잠금 단추까지 있으니 뜻을
// 설명할 필요가 없다. 그 앞에 M 을 얹어 어느 지갑인지도 말한다.
//
// 값은 크기로 치른다. W 는 아이콘을 꽉 채워 60px 에서도 뭉개지지 않았는데,
// 지갑은 여백 → 몸통 → 그 안의 글자로 세 겹이라 M 이 그만큼 작아진다.
// 몸통을 최대한 키우고 주머니를 줄여 되찾을 수 있는 만큼 되찾았지만,
// 예전 W 만큼 멀리서 잡히지는 않는다. 뜻을 얻고 크기를 내준 셈이다.
// (예전에 지구본을 걷어낸 이유가 정확히 이것이었다 — 그때와 반대로 골랐다)
//
// ⚠️ BrandMark.swift 의 walletPoints 는 아직 W 다. 스플래시에서 획이
//    그어지는 애니메이션이 그 값을 쓴다. 아이콘과 앱 첫 화면의 마크가
//    갈라져 있으므로, M 으로 맞출지 따로 정해야 한다.
// ─────────────────────────────────────────────────────────────
//
// 바탕은 스플래시와 같은 세로 그라데이션이다. 아이콘을 누르면 그 색이
// 그대로 이어져, 아이콘이 커져 화면이 된 것처럼 읽힌다.
// 값을 고칠 때는 SplashView 도 함께 고쳐야 한다.

import AppKit
import CoreGraphics
import Foundation

let size: CGFloat = 1024

guard let ctx = CGContext(data: nil,
                          width: Int(size), height: Int(size),
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("컨텍스트를 만들지 못했습니다")
}

// 좌표를 화면과 같게(위가 0) 뒤집는다.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// MARK: - 바탕

let brand = CGColor(red: 0.184, green: 0.357, blue: 0.918, alpha: 1)     // #2F5BEA
let deep = CGColor(red: 0.090, green: 0.188, blue: 0.498, alpha: 1)      // #17307F
let white = CGColor(gray: 1, alpha: 1)
// 주머니는 흰 몸통에서 한 단계만 내린 회색이다. 더 내리면 몸통에 뚫린
// 구멍처럼 보이고, 덜 내리면 주머니인지 알 수 없다.
let pocketGray = CGColor(red: 0.867, green: 0.890, blue: 0.925, alpha: 1)

let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [brand, deep] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: size / 2, y: 0),
                       end: CGPoint(x: size / 2, y: size),
                       options: [])

// MARK: - 지갑 몸통

// 가로로 누운 비율이다. 지갑은 세로로 세우면 수첩이나 카드로 보인다.
let body = CGRect(x: size * 0.090, y: size * 0.250, width: size * 0.82, height: size * 0.50)
let radius = body.height * 0.22

// 몸통 뒤로 왼쪽·아래에 물리는 뒷장. 지갑이 한 장이 아니라 접힌 것임을
// 말해 준다. 색을 새로 들이지 않고 바탕을 눌러 만든다.
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: body.offsetBy(dx: -size * 0.022, dy: size * 0.026),
                   cornerWidth: radius, cornerHeight: radius, transform: nil))
ctx.setFillColor(CGColor(gray: 0, alpha: 0.18))
ctx.fillPath()
ctx.restoreGState()

ctx.addPath(CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil))
ctx.setFillColor(white)
ctx.fillPath()

// MARK: - 주머니와 잠금 단추

// 오른쪽 끝에 물린 주머니. 몸통 밖으로 나가지 않도록 몸통 모양으로 자른다 —
// 그래야 오른쪽 끝이 몸통의 둥근 모서리를 그대로 따라간다.
let pocketWidth = body.width * 0.30
let pocket = CGRect(x: body.maxX - pocketWidth, y: body.midY - body.height * 0.20,
                    width: pocketWidth, height: body.height * 0.40)

ctx.saveGState()
ctx.addPath(CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil))
ctx.clip()
ctx.addPath(CGPath(roundedRect: pocket,
                   cornerWidth: pocket.height / 2, cornerHeight: pocket.height / 2,
                   transform: nil))
ctx.setFillColor(pocketGray)
ctx.fillPath()
ctx.restoreGState()

// 잠금 단추. 주머니 한가운데보다 조금 오른쪽에 둔다 — 가운데에 두면
// 주머니의 둥근 왼쪽 끝과 겹쳐 보인다.
let dot = min(pocket.height * 0.42, pocket.width * 0.34)
ctx.addEllipse(in: CGRect(x: pocket.midX - dot / 2 + pocket.width * 0.10,
                          y: pocket.midY - dot / 2,
                          width: dot, height: dot))
ctx.setFillColor(brand)
ctx.fillPath()

// MARK: - M

// 예전 W 와 같은 획 언어로 그린다 — 둥근 끝, 같은 굵기 비율. 마크가
// 바뀌어도 손글씨는 같은 사람의 것으로 보이게.
//
// M 은 W 를 뒤집은 모양이다. 바깥 두 획이 서고 가운데가 내려온다.
// 가운데를 바닥까지 내리지 않는 것도 W 와 같은 이유다 — 끝까지 내리면
// 네 획이 고르게 촘촘해져 M 이 아니라 지그재그로 읽힌다.
let mArea = CGRect(x: body.minX + body.width * 0.085,
                   y: body.midY - body.height * 0.255,
                   width: body.width * 0.46,
                   height: body.height * 0.51)

let mPoints = [
    CGPoint(x: 0.00, y: 1.00),
    CGPoint(x: 0.00, y: 0.00),
    CGPoint(x: 0.50, y: 0.62),
    CGPoint(x: 1.00, y: 0.00),
    CGPoint(x: 1.00, y: 1.00)
].map { CGPoint(x: mArea.minX + $0.x * mArea.width, y: mArea.minY + $0.y * mArea.height) }

ctx.setStrokeColor(brand)
ctx.setLineWidth(mArea.height * 0.30)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: mPoints[0])
for point in mPoints.dropFirst() { ctx.addLine(to: point) }
ctx.strokePath()

// MARK: - 내보내기

guard let image = ctx.makeImage() else { fatalError("이미지를 만들지 못했습니다") }
let out = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(out as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("파일을 만들지 못했습니다")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("저장하지 못했습니다") }
print("그렸습니다: \(out.path)")
