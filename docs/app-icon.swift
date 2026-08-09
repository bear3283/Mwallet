// Mwallet 앱 아이콘 1024×1024 를 그린다.
//
//   앞  W  — 지갑(Wallet). 굵기가 일정하고 끝이 둥근 기하학 마크.
//            예전 M 과 같은 획 언어라 아이콘이 바뀌어도 같은 앱으로 읽힌다.
//   뒤  구 — 지구본. 테두리와 경선·위선으로 그린 와이어프레임.
//
// 구를 원 하나로 그리지 않고 경선·위선을 넣는 것은, 원은 동전이나 점으로도
// 읽히지만 휘어진 선이 겹치면 둥근 덩어리로만 읽히기 때문이다.
//
// 작은 크기(40pt)에서는 선이 뭉개지므로, 구 안쪽을 아주 옅게 채워 둔다.
// 선이 안 보여도 W 뒤에 무언가 둥근 것이 있다는 것은 남는다.

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

// 스플래시와 같은 세로 그라데이션. 브랜드 코발트(#2F5BEA)에서 같은 계열의
// 딥 코발트(#17307F)로 떨어진다.
//
// 아이콘을 누르면 스플래시가 뜨는데, 아이콘이 단색이면 그 순간 바탕이
// 갈리며 다른 화면으로 넘어간 것처럼 보인다. 같은 색으로 이어 두면
// 아이콘이 그대로 커져 화면이 된 것처럼 읽힌다.
//
// 값을 고칠 때는 SplashView 의 그라데이션도 함께 고쳐야 한다.
let brand = CGColor(red: 0.184, green: 0.357, blue: 0.918, alpha: 1)     // #2F5BEA
let deep = CGColor(red: 0.090, green: 0.188, blue: 0.498, alpha: 1)      // #17307F

let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [brand, deep] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: size / 2, y: 0),
                       end: CGPoint(x: size / 2, y: size),
                       options: [])

// MARK: - 구

let center = CGPoint(x: size * 0.5, y: size * 0.495)
let radius = size * 0.325

func ellipsePath(rx: CGFloat, ry: CGFloat, at point: CGPoint) -> CGPath {
    CGPath(ellipseIn: CGRect(x: point.x - rx, y: point.y - ry, width: rx * 2, height: ry * 2),
           transform: nil)
}

// 안쪽을 옅게 채워 작은 크기에서도 둥근 덩어리가 남게 한다.
ctx.setFillColor(CGColor(gray: 1, alpha: 0.11))
ctx.addPath(ellipsePath(rx: radius, ry: radius, at: center))
ctx.fillPath()

ctx.setLineCap(.round)

// 테두리
ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.55))
ctx.setLineWidth(size * 0.016)
ctx.addPath(ellipsePath(rx: radius, ry: radius, at: center))
ctx.strokePath()

// 경선. 정면에서 보면 폭이 다른 타원으로 겹친다.
ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.30))
ctx.setLineWidth(size * 0.013)
for ratio in [0.34, 0.72] {
    ctx.addPath(ellipsePath(rx: radius * ratio, ry: radius, at: center))
}
// 한가운데 경선은 옆에서 본 것이라 곧은 선이 된다.
ctx.move(to: CGPoint(x: center.x, y: center.y - radius))
ctx.addLine(to: CGPoint(x: center.x, y: center.y + radius))
ctx.strokePath()

// 위선. 구 위에서는 높이마다 폭이 줄어든다 — rx = √(R² - d²).
for offset in [-radius * 0.58, 0, radius * 0.58] {
    let rx = (radius * radius - offset * offset).squareRoot()
    ctx.addPath(ellipsePath(rx: rx, ry: radius * 0.17, at: CGPoint(x: center.x, y: center.y + offset)))
}
ctx.strokePath()

// MARK: - W

// 바깥 두 획을 위로 갈수록 벌린다. 아래를 좁히고 위를 넓혀 팔을 벌린
// 모양이 되는데, 획을 얇게 잡아야 속공간이 열린 채로 남는다.
// 예전에는 바깥을 곧게 세웠지만 그러면 획 굵기에 기대게 되어 인상이
// 무거웠다.
//
// 가운데 봉우리는 위까지 올리지 않는다. 끝까지 올리면 네 획이 고르게
// 촘촘해져 W 가 아니라 지그재그로 읽힌다.
let boxWidth = size * 0.555
let boxHeight = size * 0.312
let left = center.x - boxWidth / 2
let top = center.y - boxHeight / 2

let points = [
    CGPoint(x: 0.000, y: 0.00),
    CGPoint(x: 0.215, y: 1.00),
    CGPoint(x: 0.500, y: 0.34),
    CGPoint(x: 0.785, y: 1.00),
    CGPoint(x: 1.000, y: 0.00)
].map { CGPoint(x: left + $0.x * boxWidth, y: top + $0.y * boxHeight) }

let stroke = size * 0.104

func addWPath(width: CGFloat) {
    ctx.setLineWidth(width)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)
    ctx.move(to: points[0])
    for point in points.dropFirst() { ctx.addLine(to: point) }
}

// 바탕색으로 한 번 두껍게 긋고 그 위에 흰 W 를 얹는다.
// 구의 흰 선과 W 가 맞닿는 자리에서 서로 붙어 보이지 않도록 띄우는 것이다.
//
// 이 테두리를 단색으로 칠하면 그라데이션의 아래쪽에서 바탕과 어긋나 밝은
// 자국이 남는다. 획을 면으로 바꿔 그 안에 같은 그라데이션을 다시 깐다.
ctx.saveGState()
addWPath(width: stroke + size * 0.022)
ctx.replacePathWithStrokedPath()
ctx.clip()
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: size / 2, y: 0),
                       end: CGPoint(x: size / 2, y: size),
                       options: [])
ctx.restoreGState()

ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
addWPath(width: stroke)
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
