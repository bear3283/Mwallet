//
//  BrandMark.swift
//  Mwallet
//
//  브랜드 마크 'W'. 지갑(Wallet)의 W 다.
//
//  아이콘(docs/app-icon.swift)과 같은 글자꼴을 쓴다. 다만 틀이 다르다 —
//  아이콘에서는 W 가 네모를 가득 채우고 위쪽 모서리에서 잘리지만, 여기서는
//  잘릴 테두리가 없으므로 획 끝까지 온전히 보이도록 맞춰 넣는다.
//  글자꼴은 같고 담기는 그릇만 다른 셈이다.
//
//  예전에는 뒤에 와이어프레임 지구본이 있었다. W 를 키우면서 걷어냈다 —
//  아이콘이 먼저 할 일은 뜻을 설명하는 것이 아니라 한눈에 골라지는 것이고,
//  여행이라는 뜻은 앱 안의 지도와 여행 탭이 맡는다.
//
//  아래 값을 고칠 때는 docs/app-icon.swift 도 함께 고쳐야 둘의 인상이
//  어긋나지 않는다. 아이콘은 PNG 한 장이라 코드를 공유할 수 없다.
//

import SwiftUI

enum BrandMarkGeometry {

    /// W 의 다섯 꼭짓점. 0~1 정규화 좌표라 어떤 크기로 그려도 비율이 유지된다.
    ///
    /// 바깥 두 획은 위로 갈수록 벌어진다. 아래를 좁히고 위를 넓혀 팔을 벌린
    /// 모양인데, 각도가 형태를 만들므로 획을 지나치게 굵히지 않아도 W 로 읽힌다.
    ///
    /// 가운데 봉우리는 위까지 올리지 않는다 — 끝까지 올리면 네 획이 고르게
    /// 촘촘해져 W 가 아니라 지그재그로 읽힌다.
    ///
    /// 아이콘의 0.88 × 0.74 획틀에 굵기 0.155 를 더한 것이 이 화면에 꼭 차도록
    /// 줄여 넣은 값이다. 그래서 아이콘과 견주면 미세하게 작다.
    static let walletPoints: [CGPoint] = [
        CGPoint(x: 0.0749, y: 0.1425),
        CGPoint(x: 0.2450, y: 0.8575),
        CGPoint(x: 0.5000, y: 0.3785),
        CGPoint(x: 0.7551, y: 0.8575),
        CGPoint(x: 0.9251, y: 0.1425)
    ]

    static let walletLineWidth: CGFloat = 0.1498
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

// MARK: - 마크

struct BrandMarkView: View {

    /// 획이 그어지는 진행도.
    var progress: CGFloat = 1
    var color: Color = .white

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            WalletMark(progress: progress)
                .stroke(color,
                        style: StrokeStyle(lineWidth: BrandMarkGeometry.walletLineWidth * side,
                                           lineCap: .round,
                                           lineJoin: .round))
        }
        .aspectRatio(1, contentMode: .fit)
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
