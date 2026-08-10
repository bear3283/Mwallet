// Mwallet 앱 아이콘 1024×1024 를 그린다.
//
// W 하나가 아이콘을 가득 채운다. 지갑(Wallet)의 W 다.
//
// 예전에는 뒤에 와이어프레임 지구본을 두어 '여행' 을 함께 담았다. 담기는
// 뜻은 늘었지만 W 가 그만큼 작아졌고, 홈 화면의 다른 아이콘들 사이에서
// 눈에 띄지 않았다. 아이콘이 먼저 할 일은 뜻을 설명하는 것이 아니라
// 한눈에 골라지는 것이라, 뜻을 덜고 크기를 얻었다.
// (여행이라는 뜻은 앱 안의 지도와 여행 탭이 맡는다)
//
// 획이 위쪽 모서리에서 잘린다. 일부러 그렇게 뒀다 — 테두리 안에 얌전히
// 들어앉는 것보다, 틀보다 큰 것이 들어 있는 편이 눈을 끈다.
//
// 바탕은 스플래시와 같은 세로 그라데이션이다. 아이콘을 누르면 그 색이
// 그대로 이어져, 아이콘이 커져 화면이 된 것처럼 읽힌다.
// 값을 고칠 때는 SplashView 와 BrandMarkGeometry 도 함께 고쳐야 한다.

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

let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [brand, deep] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: size / 2, y: 0),
                       end: CGPoint(x: size / 2, y: size),
                       options: [])

// MARK: - W

// 바깥 두 획은 위로 갈수록 벌어진다. 아래를 좁히고 위를 넓혀 팔을 벌린
// 모양인데, 각도가 형태를 만들므로 획을 지나치게 굵히지 않아도 W 로 읽힌다.
//
// 가운데 봉우리는 위까지 올리지 않는다. 끝까지 올리면 네 획이 고르게
// 촘촘해져 W 가 아니라 지그재그로 읽힌다.
let boxWidth = size * 0.88
let boxHeight = size * 0.74
let left = size / 2 - boxWidth / 2
let top = size * 0.150

let points = [
    CGPoint(x: 0.000, y: 0.00),
    CGPoint(x: 0.200, y: 1.00),
    CGPoint(x: 0.500, y: 0.33),
    CGPoint(x: 0.800, y: 1.00),
    CGPoint(x: 1.000, y: 0.00)
].map { CGPoint(x: left + $0.x * boxWidth, y: top + $0.y * boxHeight) }

let stroke = size * 0.155

ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
ctx.setLineWidth(stroke)
ctx.setLineJoin(.round)
ctx.setLineCap(.round)
ctx.move(to: points[0])
for point in points.dropFirst() { ctx.addLine(to: point) }
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
