//
//  BrandMark.swift
//  Mwallet
//
//  브랜드 마크 'W + 지구본'.
//
//    앞  W  — 지갑(Wallet). 바깥 두 획을 곧게 세우고 가운데만 솟게 한 모양.
//    뒤  구 — 지구본. 테두리와 경선·위선으로 그린 와이어프레임.
//
//  앱 아이콘(docs/app-icon.swift)과 같은 좌표를 쓴다. 아이콘은 PNG 한 장이라
//  코드를 공유할 수 없으므로, 아래 BrandMarkGeometry 의 값과 아이콘 스크립트의
//  값을 함께 고쳐야 둘의 인상이 어긋나지 않는다.
//
//  스플래시에서는 구가 먼저 떠오르고 그 위에 W 가 그어진다.
//  '세상이 있고, 거기에 기록을 남긴다' 는 순서다.
//

import SwiftUI

enum BrandMarkGeometry {

    // 0~1 정규화 좌표. 어떤 크기로 그려도 비율이 유지된다.
    static let globeCenter = CGPoint(x: 0.5, y: 0.495)
    static let globeRadius: CGFloat = 0.325

    /// W 의 다섯 꼭짓점.
    ///
    /// 바깥 두 획은 위로 갈수록 벌어진다. 아래를 좁히고 위를 넓혀 팔을 벌린
    /// 모양인데, 획을 얇게 잡아야 속공간이 열린 채로 남는다.
    ///
    /// 가운데 봉우리는 위까지 올리지 않는다 — 끝까지 올리면 네 획이 고르게
    /// 촘촘해져 W 가 아니라 지그재그로 읽힌다.
    static let walletPoints: [CGPoint] = [
        CGPoint(x: 0.2225, y: 0.3390),
        CGPoint(x: 0.3418, y: 0.6510),
        CGPoint(x: 0.5000, y: 0.4451),
        CGPoint(x: 0.6582, y: 0.6510),
        CGPoint(x: 0.7775, y: 0.3390)
    ]

    static let walletLineWidth: CGFloat = 0.104
    static let globeOutlineWidth: CGFloat = 0.016
    static let globeGridWidth: CGFloat = 0.013

    /// 경선의 가로 반지름 비율. 정면에서 보면 폭이 다른 타원으로 겹친다.
    static let meridianRatios: [CGFloat] = [0.34, 0.72]
    /// 위선의 높이. 구 위에서는 높이마다 폭이 줄어든다 — rx = √(R² - d²).
    static let parallelOffsets: [CGFloat] = [-0.58, 0, 0.58]
    static let parallelFlatness: CGFloat = 0.17
}

// MARK: - W

struct WalletMark: Shape {

    /// 획이 그어지는 진행도. 스플래시에서 0 → 1 로 애니메이션한다.
    var progress: CGFloat = 1

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = BrandMarkGeometry.walletPoints.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path.trimmedPath(from: 0, to: max(0, min(1, progress)))
    }
}

// MARK: - 구

/// 구의 테두리. 안쪽을 옅게 채울 때도 이 모양을 쓴다.
struct GlobeOutline: Shape {

    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: BrandMarkGeometry.ellipseRect(rx: BrandMarkGeometry.globeRadius,
                                                      ry: BrandMarkGeometry.globeRadius,
                                                      in: rect))
    }
}

/// 경선과 위선. 원 하나만으로는 동전이나 점으로도 읽히지만,
/// 휘어진 선이 겹치면 둥근 덩어리로만 읽힌다.
struct GlobeGrid: Shape {

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = BrandMarkGeometry.globeRadius

        for ratio in BrandMarkGeometry.meridianRatios {
            path.addEllipse(in: BrandMarkGeometry.ellipseRect(rx: radius * ratio, ry: radius, in: rect))
        }

        // 한가운데 경선은 옆에서 본 것이라 곧은 선이 된다.
        let center = BrandMarkGeometry.point(BrandMarkGeometry.globeCenter, in: rect)
        path.move(to: CGPoint(x: center.x, y: center.y - radius * rect.height))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius * rect.height))

        for offset in BrandMarkGeometry.parallelOffsets {
            let distance = radius * offset
            let rx = (radius * radius - distance * distance).squareRoot()
            path.addEllipse(in: BrandMarkGeometry.ellipseRect(rx: rx,
                                                              ry: radius * BrandMarkGeometry.parallelFlatness,
                                                              in: rect,
                                                              dy: distance))
        }
        return path
    }
}

private extension BrandMarkGeometry {

    static func point(_ normalized: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + normalized.x * rect.width,
                y: rect.minY + normalized.y * rect.height)
    }

    static func ellipseRect(rx: CGFloat, ry: CGFloat, in rect: CGRect, dy: CGFloat = 0) -> CGRect {
        let center = point(globeCenter, in: rect)
        let width = rx * rect.width
        let height = ry * rect.height
        return CGRect(x: center.x - width,
                      y: center.y + dy * rect.height - height,
                      width: width * 2,
                      height: height * 2)
    }
}

// MARK: - 마크

struct BrandMarkView: View {

    /// W 획이 그어지는 진행도.
    var progress: CGFloat = 1
    /// 구가 떠오르는 정도. W 보다 먼저 나타난다.
    var globeOpacity: Double = 1
    var color: Color = .white

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            ZStack {
                globe(side: side)
                    .opacity(globeOpacity)

                WalletMark(progress: progress)
                    .stroke(color,
                            style: StrokeStyle(lineWidth: BrandMarkGeometry.walletLineWidth * side,
                                               lineCap: .round,
                                               lineJoin: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // 작은 크기에서는 선이 뭉개지므로 안쪽을 옅게 채운다.
    // 선이 안 보여도 W 뒤에 둥근 것이 있다는 인상은 남는다.
    private func globe(side: CGFloat) -> some View {
        ZStack {
            GlobeOutline()
                .fill(color.opacity(0.11))

            GlobeOutline()
                .stroke(color.opacity(0.55), lineWidth: BrandMarkGeometry.globeOutlineWidth * side)

            GlobeGrid()
                .stroke(color.opacity(0.30), lineWidth: BrandMarkGeometry.globeGridWidth * side)
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.mainAccent, Color(0x17307F)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        BrandMarkView()
            .frame(width: 200, height: 200)
    }
}
